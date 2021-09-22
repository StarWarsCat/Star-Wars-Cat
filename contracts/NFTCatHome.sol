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

    uint public foodReward; // 猫粮奖励
    uint[2][] public foodPerson;
    uint public foodTotal; // 猫粮抽奖的权重总数
    uint constant foodRewardsNeedTimes = 100;

    uint public sysCatFood;

    uint[] public canFeedGrade;

    struct phaseData {
        uint grade; // 投食中奖系列ID
        uint[10] feedData; // 投食总数
        uint feedAward; // 投食奖励
        uint feedPerson; // 投食人数
        uint foodAward; // 猫粮奖励
        address foodAwardAddr; // 猫粮奖励地址
        mapping(address => uint[10]) feedInfo; // 玩家投食明细
        mapping(address => bool) gotRewardsAddr; // 已领取奖励地址
    }
    mapping(uint => phaseData) private phase; // 每一期的结果数据

    event FETCH(address indexed _sender, uint _id, uint _award, uint _foodAward);
    event OPENRWARDS(uint _id, uint _grade);
    event FEED(address indexed _sender, uint _grade, uint _times);

//    constructor(address _catAddr, address _shopAddr, address _feeTo, bool _product) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        shopAddr = IShop(_shopAddr);
//        feeTo = _feeTo;
//        endTime = block.timestamp.div(homeInterval).add(1).mul(homeInterval) - 300;
//        currentID = 1;
//        auth[msg.sender] = true;
//    }

    function __NFTCatHome_init(address _catAddr, address _shopAddr, address _feeTo, bool _product) public initializer {
        BaseUpgradeable.__Base_init();
        XYZConfig.__XYZConfig_init(_product);
        Random.__Random_init();
        catAddr = ICat(_catAddr);
        shopAddr = IShop(_shopAddr);
        feeTo = _feeTo;
        endTime = block.timestamp.div(homeInterval).add(1).mul(homeInterval) - 300;
        currentID = 1;
        auth[msg.sender] = true;
        feedReward = 0; // 领养奖池
        foodReward = 0; // 投喂奖池
        foodTotal = 0; // 猫粮抽奖的权重总数
        canFeedGrade = [1, 2, 3, 4, 7];
    }

    function setCanFeedGrade(uint[] memory _data) external onlyAdmin {
        canFeedGrade = _data;
    }

    function giveFoodReward(uint _seed) internal {
        // 达到100次 抽奖
        uint _rand = uint(keccak256(abi.encodePacked(_seed, msg.sender, block.timestamp, block.coinbase, gasleft()))) % foodTotal;
        uint _sum = 0;
        for (uint i = 0; i < foodPerson.length; i++) {
            _sum = _sum.add(foodPerson[i][1]);
            if (_sum > _rand) {
                phaseData storage _d = phase[currentID];
                _d.foodAward = foodReward;
                _d.foodAwardAddr = address(uint160(foodPerson[i][0]));

                // 清空猫粮奖励
                foodReward = 0;
                delete foodPerson;
                foodTotal = 0;
            }
        }
    }

    function feed(uint _grade, uint _times) external lock notPaused onlyExternal {
        require(block.timestamp < endTime, "block.timestamp < endTime");
        require(_times > 0, "_times > 0");
        require(_grade > 0 && _grade < 11, "_grade > 0 && _grade < 11");

        // 扣除投食费用
        uint feedFee = _times.mul(1e9);
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

    // 查询当前一期状态  当前期数  结束时间  投食人数
    function query() external view returns (uint, uint, uint, uint[10] memory, uint[10] memory, uint) {
        return (currentID, endTime, phase[currentID].feedPerson, phase[currentID].feedInfo[msg.sender],
            phase[currentID].feedData, feedReward);
    }

    struct hisData {
        uint id; // 期数
        uint[10] feedData; // 投食总数
        uint[10] myFeedData; // 我的投食总数
        uint feedAward; // 投食奖励
        uint foodAward; // 猫粮奖励
        address foodAwardAddr; // 猫粮奖励地址
        bool gotReward; //是否已领取奖励
    }

    // 查询每一期的获奖记录
    function history(uint _start, uint _end) external view returns (hisData[] memory) {
        require(_end < currentID, "_end < currentID");
        require(_end >= _start, "_end >= _start");

        hisData[] memory his = new hisData[](_end - _start + 1);
        for (uint i = _start; i < _end + 1; i++) {
            his[i - _start].id = i;
            his[i - _start].feedData = phase[i].feedData;
            his[i - _start].myFeedData = phase[i].feedInfo[msg.sender];
            his[i - _start].feedAward = phase[i].feedAward;
            his[i - _start].foodAward = phase[i].foodAward;
            his[i - _start].foodAwardAddr = phase[i].foodAwardAddr;
            his[i - _start].gotReward = phase[i].gotRewardsAddr[msg.sender];
        }

        return his;
    }

    // 领取奖励
    function fetch(uint _id) external lock notPaused onlyExternal {
        require(_id < currentID, "_id < currentID");
        // 还没有领奖
        require(!phase[_id].gotRewardsAddr[msg.sender], "!phase[_id].gotRewardsAddr[msg.sender]");

        // 判断是否中了猫粮奖励
        if (phase[_id].foodAwardAddr == msg.sender) {
            shopAddr.addItem(msg.sender, catFood, phase[_id].foodAward);
        }

        // 该期开出的猫系列
        uint grade = phase[_id].grade;
        // 玩家该期该系列喂食情况
        uint userFeed = phase[_id].feedInfo[msg.sender][grade];
        uint award = 0;
        if (userFeed > 0) { // 玩家买中了
            uint sysFeedInfo = phase[_id].feedData[grade];
            award = phase[_id].feedAward.mul(userFeed).div(sysFeedInfo);
            shopAddr.addItem(msg.sender, catFood, award);
            phase[_id].gotRewardsAddr[msg.sender] = true;
        }

        emit FETCH(msg.sender, _id, award, phase[_id].foodAward);
    }
}
