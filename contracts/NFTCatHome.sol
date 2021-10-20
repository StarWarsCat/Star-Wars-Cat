// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import './XYZConfig.sol';
import './Random.sol';
import './IShop.sol';

contract NFTCatHome is XYZConfig, BaseUpgradeable, Random {
    using SafeMath for uint;
    ICat public catAddr;
    IShop public shopAddr;
    address public feeTo;

    uint public endTime;

    uint public feedReward; // 投食奖励
    uint public currentID;
    uint public currentFoodID;

    uint public foodReward; // 猫粮奖励
    uint[2][] public foodPerson;
    uint public foodTotal; // 猫粮抽奖的权重总数
    uint constant foodRewardsNeedTimes = 100;

    uint public sysCatFood;

    uint[] public canFeedGrade;

    //////////// 领养奖池
    struct phaseData {
        uint grade; // 领养奖池中奖系列ID
        uint[10] feedData; // 投食总数
        uint feedAward; // 投食奖励
        uint feedPerson; // 投食人数

        mapping(address => uint[10]) feedInfo; // 玩家投食明细
        mapping(address => bool) gotFeedRewardsAddr; // 已领取领养奖池奖励地址

    }
    mapping(uint => phaseData) private phase; // 每一期的结果数据


    // 猫咪中奖记录
    struct hisData {
        uint id; // 期数
        uint grade; // 投食中奖系列ID
        uint[10] feedData; // 投食总数
        uint[10] myFeedData; // 我的投食总数
        uint feedAward; // 投食奖励
        bool gotFeedReward; // 已领取领养奖池奖励地址
    }

    //////////// 投喂奖池（每投喂100次开奖）
    struct foodPhaseData {
        uint foodAward; // 猫粮奖励
        uint myFoodNum; // 我的投食总数
        uint foodTotal; // 总的投食总数
        address foodAwardAddr; // 猫粮奖励地址
        bool gotFoodReward; //是否已领取投喂奖池奖励
        mapping(address => uint) foodNum; // 玩家投食总数
    }
    mapping(uint => foodPhaseData) private foodPhase; // 每一期的结果数据

    // 返回每100期中奖记录
    struct foodHisData {
        uint id; // 期数
        uint foodAward; // 猫粮奖励
        uint myFoodNum; // 我的投食总数
        uint foodTotal; // 总的投食总数
        address foodAwardAddr; // 猫粮奖励地址
        bool gotFoodReward; //是否已领取投喂奖池奖励
    }

    event FETCH(address indexed _sender, uint[] _ids);
    event OPENRWARDS(uint _id, uint _grade);
    event FEED(address indexed _sender, uint _grade, uint _times);
    event FEEDAWARDFETCH(address indexed _sender, uint[] _ids);

//    constructor(address _catAddr, address _shopAddr, address _feeTo, bool _product) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        shopAddr = IShop(_shopAddr);
//        feeTo = _feeTo;
//        endTime = block.timestamp.div(homeInterval).add(1).mul(homeInterval) - 300;
//        currentID = 1;
//        auth[msg.sender] = true;
//    }

    function initialize(address _catAddr, address _shopAddr, address _feeTo, bool _product) public initializer {
        BaseUpgradeable.__Base_init();
        XYZConfig.__XYZConfig_init(_product);
        Random.__Random_init();
        catAddr = ICat(_catAddr);
        shopAddr = IShop(_shopAddr);
        feeTo = _feeTo;
        endTime = block.timestamp.div(homeInterval).add(1).mul(homeInterval) - 300;
        currentID = 1;
        currentFoodID = 1;
        auth[msg.sender] = true;
        feedReward = 0; // 领养奖池
        foodReward = 0; // 投喂奖池
        foodTotal = 0; // 猫粮抽奖的权重总数
        canFeedGrade = [1, 2, 3, 4];
    }

    function setCanFeedGrade(uint[] memory _data) external onlyAdmin {
        canFeedGrade = _data;
    }

    function setEndTime(uint _endTime) external onlyAdmin {
        endTime = _endTime;
    }

    // 查看奖池
    function getfoodPersonNum() external view returns (uint, uint) {
        uint mySum = 0;
        for (uint j = 0; j < foodPerson.length; j++) {
            if (msg.sender == address(uint160(foodPerson[j][0]))) {
                mySum = mySum.add(foodPerson[j][1]);
            }
        }

        return (foodPerson.length, mySum);
    }

    function giveFoodReward(uint _seed) internal {
        // 达到100次 抽奖
        uint _rand = uint(keccak256(abi.encodePacked(_seed, msg.sender, block.timestamp, block.coinbase, gasleft()))) % foodTotal;
        uint _sum = 0;

        for (uint i = 0; i < foodPerson.length; i++) {
            _sum = _sum.add(foodPerson[i][1]);
            if (_sum > _rand) {
                foodPhaseData storage _fd = foodPhase[currentFoodID];
                _fd.foodAward = foodReward;
                _fd.foodTotal = foodTotal;
                _fd.foodAwardAddr = address(uint160(foodPerson[i][0]));

                // 清空猫粮奖励
                foodReward = 0;
                delete foodPerson;
                foodTotal = 0;
            }
        }
        currentFoodID = currentFoodID.add(1);
    }

    function feed(uint _grade, uint _times) external lock notPaused onlyExternal {
        require(block.timestamp < endTime, "block.timestamp < endTime");
        require(_times > 0, "_times > 0");
        require(_grade > 0 && _grade < 11, "_grade > 0 && _grade < 11");

        // 扣除投食份数
        uint feedFee = _times.mul(1e18);
        shopAddr.delItem(msg.sender, catFood, feedFee);

        feedReward = feedReward.add(feedFee.mul(70).div(100));  // 领养奖池
        foodReward = foodReward.add(feedFee.mul(20).div(100));  // 投喂奖池
        sysCatFood = sysCatFood.add(feedFee.mul(10).div(100));

        // 记录本期的投食总数
        phaseData storage _d = phase[currentID];
        _d.feedData[_grade] = _d.feedData[_grade].add(_times);
        if (_d.feedInfo[msg.sender][0] == 0) { // 如果该玩家还没有喂养过
            _d.feedPerson = _d.feedPerson.add(1);
        }

        // 保存玩家投食记录
        _d.feedInfo[msg.sender][_grade] = _d.feedInfo[msg.sender][_grade].add(_times);
        _d.feedInfo[msg.sender][0] = _d.feedInfo[msg.sender][0].add(_times); // 保存玩家总的投食次数

        // 保存到抽奖猫粮奖励的记录
        foodPerson.push([uint160(msg.sender), _times]);
        foodTotal = foodTotal.add(_times);
        if (foodPerson.length == foodRewardsNeedTimes) { // 达到100次 就需要发放猫粮奖励
            giveFoodReward(foodTotal);
        }

        emit FEED(msg.sender, _grade, _times);
    }

    // 开奖
    function openRewards() external onlyAuth {
        uint luckyGrade = rand_list(canFeedGrade);

        phaseData storage _d = phase[currentID];
        _d.grade = luckyGrade;
        if (_d.feedData[luckyGrade] > 0) { // 有人中奖
            _d.feedAward = feedReward;
            // 清空投食奖励
            feedReward = 0;
        }

        emit OPENRWARDS(currentID, luckyGrade);

        currentID = currentID.add(1);
        // 新的一期倒计时
        endTime = block.timestamp.div(homeInterval).add(2).mul(homeInterval) - 300;
    }

    // 查看奖池
    function getReward() external view returns (uint[2] memory) {
        return [feedReward, foodReward];
    }

    // 查看当前期数
    function getID() external view returns (uint[2] memory) {
        return [currentID, currentFoodID];
    }

    // 查询当前一期状态  当前期数  结束时间  投食人数 玩家投食明细 投食总数
    function query() external view returns (uint, uint, uint, uint[10] memory, uint[10] memory) {
        return (currentID, endTime, phase[currentID].feedPerson, phase[currentID].feedInfo[msg.sender],
            phase[currentID].feedData);
    }

    function testqq() external view returns (uint) {
        uint foodTotal = 103;
        uint _rand = uint(keccak256(abi.encodePacked(foodTotal, msg.sender, block.timestamp, block.coinbase, gasleft()))) % foodTotal;
        return _rand;
    }

    // 查询领养奖池每一期的获奖记录
    function history(uint _start, uint _end) external view returns (hisData[] memory) {
        require(_end < currentID, "_end < currentID");
        require(_end >= _start, "_end >= _start");

        hisData[] memory his = new hisData[](_end - _start + 1);
        for (uint i = _start; i < _end + 1; i++) {
            his[i - _start].id = i;
            his[i - _start].grade = phase[i].grade;
            his[i - _start].feedData = phase[i].feedData;
            his[i - _start].myFeedData = phase[i].feedInfo[msg.sender];
            his[i - _start].feedAward = phase[i].feedAward;
            his[i - _start].gotFeedReward = phase[i].gotFeedRewardsAddr[msg.sender];
        }

        return his;
    }


    // 查询投喂奖池每100期的开奖记录
    function foodHistory(uint _start, uint _end) external view returns (foodHisData[] memory) {
        require(_end < currentFoodID, "_end < currentFoodID");
        require(_end >= _start, "_end >= _start");

        foodHisData[] memory fdHis = new foodHisData[](_end - _start + 1);
        for (uint i = _start; i < _end + 1; i++) {
            fdHis[i - _start].id = i;
            fdHis[i - _start].foodAward = foodPhase[i].foodAward;
            fdHis[i - _start].foodAwardAddr = foodPhase[i].foodAwardAddr;
            fdHis[i - _start].myFoodNum = foodPhase[i].myFoodNum;
            fdHis[i - _start].foodTotal = foodPhase[i].foodTotal;
            fdHis[i - _start].gotFoodReward = foodPhase[i].gotFoodReward;
        }

        return fdHis;
    }

    // 领取投喂奖池
    function fetch(uint[] memory _ids) external lock notPaused onlyExternal {
        for (uint i = 0; i < _ids.length; i++) {
            uint _id = _ids[i];
            require(_id < currentFoodID, "_id < currentFoodID");
            // 还没有领奖
            require(!foodPhase[_id].gotFoodReward, "not gotFoodReward");

            // 判断是否中了猫粮奖励
            if (foodPhase[_id].foodAwardAddr == msg.sender) {
                shopAddr.addItem(msg.sender, catFood, foodPhase[_id].foodAward);
                foodPhase[_id].gotFoodReward = true;
            }
        }

        emit FETCH(msg.sender, _ids);
    }

    // 领取领养奖池
    function feedAwardFetch(uint[] memory _ids) external lock notPaused onlyExternal {
        for (uint i = 0; i < _ids.length; i++) {
            uint _id = _ids[i];
            require(_id < currentID, "_id < currentID");
            // 还没有领奖
            require(!phase[_id].gotFeedRewardsAddr[msg.sender], "not gotFeedRewardsAddr");

            // 该期开出的猫系列
            uint grade = phase[_id].grade;
            // 玩家该期该系列喂食情况
            uint userFeed = phase[_id].feedInfo[msg.sender][grade];
            uint award = 0;
            if (userFeed > 0) { // 玩家买中了
                uint sysFeedInfo = phase[_id].feedData[grade];  // 该系列投食总数
                award = phase[_id].feedAward.mul(userFeed).div(sysFeedInfo);
                shopAddr.addItem(msg.sender, catFood, award);
                phase[_id].gotFeedRewardsAddr[msg.sender] = true;
            }
        }

        emit FEEDAWARDFETCH(msg.sender, _ids);
    }

}
