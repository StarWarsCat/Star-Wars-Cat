// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./INFT.sol";
import "./Random.sol";
import "./XYZConfig.sol";

// lp接口 含质押 赎回 余额等
contract LPTokenWrapper is BaseUpgradeable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint private _totalSupply;
    mapping(address => uint) private _balances;

    address public kSwapLP;
    address public aToken;


//    constructor(address _kSwapLP, address _aToken) {
//        kSwapLP = _kSwapLP;
//        aToken = _aToken;
//    }

    function __LPTokenWrapper_init(address _kSwapLP, address _aToken) public initializer {
        require(_kSwapLP != address(0), "_kSwapLP != address(0)");
        require(_aToken != address(0), "_aToken != address(0)");

        kSwapLP = _kSwapLP;
        aToken = _aToken;
    }

    /**
     * @dev set kSwapLP Token address
     * @param _kSwapLP kSwapLP Token contract address
     */
    function setKSwapLP(address _kSwapLP) external onlyAdmin returns (bool) {
        require(_kSwapLP != address(0), "_kSwapLP != address(0)");

        kSwapLP = _kSwapLP;
        return true;
    }

    /**
     * @dev set AToken address
     * @param _aToken AToken contract address
     */
    function setAToken(address _aToken) external onlyAdmin returns (bool) {
        require(_aToken != address(0), "_aToken != address(0)");

        aToken = _aToken;
        return true;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }

    function stake(uint amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        IERC20(kSwapLP).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        IERC20(kSwapLP).safeTransfer(msg.sender, amount);
    }
}


contract LPPool is LPTokenWrapper, Random, XYZConfig {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint stakeAmount;       // 质押数量
        uint withdrawnAmount;   // 已领取数量
        uint preInterestPer;    // 上次计算每股收益数值
        uint accInterest;       // 当前累计收益数值
    }

    // 矿池产出衰减周期
    uint constant INTEREST_CYCLE = 3 hours;
    // 矿池生命周期
    uint constant POOL_LIFE_CYCLE = 100 days;
    // 矿池产出衰减期数
    uint constant CYCLE_TIMES = POOL_LIFE_CYCLE / INTEREST_CYCLE;
    uint INTEREST_RATE = 800; // 千分比 衰减系数

    uint constant DECIMALS = 10 ** 18;
    // uint constant TOTAL_INTEREST = 6999993 * DECIMALS;
    // mint BToken amount each week
    uint INTEREST_BASE_AMOUNT = 1617034 * DECIMALS;

    uint public startTime = type(uint).max;
    uint public endTime = type(uint).max;
    // time of the first user stake, pool live start at this time
    uint public firstStakeTime = 0;
    // 上次更新每股收益时间
    uint public lastInterestUpdateTime = 0;
    // 矿池累计每股派息
    uint public accInterestPer = 0;

    mapping(address => UserInfo) users;

    event Stake(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    event WithdrawReward(address indexed user, uint reward);
    event SetStartTime(address indexed _admin, uint _startTime);
    event SetEndTime(address indexed _admin, uint _endTime);

//    constructor(address _kSwapLP, address _aToken, bool _production) LPTokenWrapper(_kSwapLP, _aToken) XYZConfig(_production) {}

    function __LPPool_init(address _kSwapLP, address _aToken, bool _production) public initializer {
        LPTokenWrapper.__LPTokenWrapper_init(_kSwapLP, _aToken);
        Random.__Random_init();
        XYZConfig.__XYZConfig_init(_production);
    }

    modifier checkStart() {
        require(block.timestamp > startTime, "checkStart: block.timestamp > startTime");
        _;
    }

    /**
     * @dev get the end time of pool V1
     */
    function getEndTime() public view returns (uint) {
        return endTime;
    }

    /**
     * @dev total released bToken currently
     */
    function totalRelease() external view returns (uint) {
        if (0 == firstStakeTime) {
            return 0;
        }
        return calculateInterest(firstStakeTime, block.timestamp);
    }

    /**
     * @dev set pool start time
     * @param _startTime time to active pool V1
     */
    function setStartTime(uint _startTime) external onlyAdmin returns (bool) {
        require(block.timestamp < _startTime, "block.timestamp < _startTime");
        startTime = _startTime;

        emit SetStartTime(admin, _startTime);

        return true;
    }

    /**
     * @dev set pool end time
     * @param _endTime time of pool stopped
     */
    function setEndTime(uint _endTime) external onlyAdmin returns (bool) {
        require(0 < firstStakeTime, "setEndTime: 0 < firstStakeTime");
        require(block.timestamp <= _endTime, "setEndTime: block.timestamp <= _endTime");
        require(firstStakeTime + POOL_LIFE_CYCLE > _endTime, "setEndTime: firstStakeTime + POOL_LIFE_CYCLE > _endTime");
        endTime = _endTime;

        emit SetEndTime(admin, _endTime);

        return true;
    }

    function stake(uint256 _amount) public override lock checkStart {
        require(endTime > block.timestamp, "stake: endTime > block.timestamp");
        require(0 < _amount, "stake: 0 < _amount");

        // update firstStakeTime & endTime at the first user stake
        if (0 == firstStakeTime) {
            firstStakeTime = block.timestamp;
            endTime = firstStakeTime + POOL_LIFE_CYCLE;
        }

        // 更新矿池累计每股派息和用户利息
        updateInterest();
        // 增加用户质押数量
        // users[msg.sender].stakeAmount = users[msg.sender].stakeAmount.add(_amount);

        super.stake(_amount);

        emit Stake(msg.sender, _amount);
    }

    function withdraw(uint _amount) public override lock checkStart {
        require(0 < _amount, "withdraw: 0 < _amount");

        // 更新矿池累计每股派息和用户利息
        updateInterest();
        // 减少用户质押数量
        // users[msg.sender].stakeAmount = users[msg.sender].stakeAmount.sub(_amount);

        super.withdraw(_amount);

        emit Withdraw(msg.sender, _amount);
    }

    uint bornSeconds = 10 days; // 怀孕周期
    uint public feedInterval = 1 days; // 喂食间隔

    uint constant boxCP = 10_0000 * DECIMALS; // 每个盒子需要消耗cp数
    uint[] public boxList = [400, 300, 200, 100];

    // 生成一个NFT结构数据
    function genCat(uint _grade) internal returns(ICat.TokenInfo memory ti) {
        ti.grade = uint8(_grade);
        uint _rand = rand100();
        ti.sex = MALE;
        if (_rand < female_cat_rate) {
            ti.sex = FEMALE;
        }
        ti.stype = uint8(rand_weight(boxList)); // 随机猫属于哪个系列
        ti.tokenId = ICat(aToken).currentTokenId() + 1;
        ti.endTime = block.timestamp + bornSeconds;
        ti.feedTime = block.timestamp + feedInterval;
        ti.initTime = block.timestamp;
        ti.step = STEP_BABY;
    }

    function giveCat(uint _cp) internal returns (uint){
        uint catNum = 0;
        if (_cp > boxCP * 30) {
            catNum = 30;
        } else {
            catNum = _cp.div(boxCP);
        }

        for (uint i = 0; i < catNum; i++) {
            ICat.TokenInfo memory ti = genCat(7);
            boxList[ti.stype] = boxList[ti.stype].sub(1);
            ICat(aToken).mintOnlyBy(msg.sender, ti.tokenId, ti);
        }

        return catNum.mul(boxCP);
    }

    function withdrawReward() public checkStart onlyExternal {
        // 更新矿池累计每股派息和用户利息
        updateInterest();

        uint userInterest = users[msg.sender].accInterest;
        if (userInterest > 0) {
            uint useCP = giveCat(userInterest);
            users[msg.sender].accInterest = userInterest.sub(useCP);
            users[msg.sender].withdrawnAmount = users[msg.sender].withdrawnAmount.add(useCP);

            emit WithdrawReward(msg.sender, useCP);
        }
    }


    // 返回我的算力 产出速度 已领取奖励 待领取奖励
    function myPoolInfo() external view returns (uint[4] memory) {
        if (0 == totalSupply()) {
            return [0, 0, users[msg.sender].withdrawnAmount, users[msg.sender].accInterest];
        }

        uint bTokenPerSecond = calculateInterest(block.timestamp - 1, block.timestamp);
        uint speed = bTokenPerSecond.mul(balanceOf(msg.sender)).div(totalSupply());

        // current accumulating interest from lastInterestUpdateTime to now
        uint currAccInterest = calculateInterest(lastInterestUpdateTime, block.timestamp);
        uint currAccInterestPer = accInterestPer.add(currAccInterest.mul(DECIMALS).div(totalSupply()));

        // userInterest = user_stake_amount * (accInterestPer - user_preInterestPer)
        uint userInterest = balanceOf(msg.sender).mul(currAccInterestPer.sub(users[msg.sender].preInterestPer)).div(DECIMALS);
        uint currUserInterest = users[msg.sender].accInterest.add(userInterest);

        return [balanceOf(msg.sender), speed, users[msg.sender].withdrawnAmount, currUserInterest];
    }

    /**
     * @dev update accInterestPer & user interest
     * 更新矿池累计每股派息和用户利息
     */
    function updateInterest() internal {
        // 1 >> update accInterestPer
        if (0 < totalSupply()) {
            // current accumulating interest from lastInterestUpdateTime to now
            uint currAccInterest = calculateInterest(lastInterestUpdateTime, block.timestamp);
            // update accInterestPer
            accInterestPer = accInterestPer.add(currAccInterest.mul(DECIMALS).div(totalSupply()));
            // update lastInterestUpdateTime
            lastInterestUpdateTime = block.timestamp;
        }

        // 2 >> update user interest
        // userInterest = user_stake_amount * (accInterestPer - user_preInterestPer)
        uint userInterest = balanceOf(msg.sender).mul(accInterestPer.sub(users[msg.sender].preInterestPer)).div(DECIMALS);
        users[msg.sender].accInterest = users[msg.sender].accInterest.add(userInterest);
        // update user preInterestPer
        users[msg.sender].preInterestPer = accInterestPer;
    }

    /**
     * @dev 计算一段时间内矿池产生的利息
     * @param _startTime time to start with
     * @param _endTime time to end at
     */
    function calculateInterest(uint _startTime, uint _endTime) public view returns (uint interest) {
        // require(0 < firstStakeTime, "0 < firstStakeTime");
        if (0 == firstStakeTime) {
            return 0;
        }
        // require(firstStakeTime <= _startTime, "firstStakeTime <= _startTime");
        if (firstStakeTime > _startTime) {
            _startTime = firstStakeTime;
        }
        if (endTime < _endTime) {
            _endTime = endTime;
        }
        // require(_startTime < _endTime, "_startTime < _endTime");
        if (_startTime >= _endTime) {
            return 0;
        }

        // 下面的逻辑就是分段计算所有利息，可用跨段计算
        uint index1 = (_startTime - firstStakeTime) / INTEREST_CYCLE;
        uint index2 = (_endTime - firstStakeTime) / INTEREST_CYCLE;
        if (index1 == index2) {//同一段
            interest = INTEREST_BASE_AMOUNT * ((INTEREST_RATE / 1000) ** index1) * (_endTime - _startTime) / INTEREST_CYCLE;
            return interest;
        }
        for (uint i = index1; i < CYCLE_TIMES; i++) {//不同段
            if (i == index1 && i < index2) {
                interest = INTEREST_BASE_AMOUNT * ((INTEREST_RATE / 1000) ** i) * (firstStakeTime + (i + 1) * INTEREST_CYCLE - _startTime) / INTEREST_CYCLE;
            }
            if (index1 < i && i < index2) {
                interest = interest + INTEREST_BASE_AMOUNT * ((INTEREST_RATE / 1000) ** i);
            }
            if (i == index2) {
                interest = interest + INTEREST_BASE_AMOUNT * ((INTEREST_RATE / 1000) ** i) * (_endTime - (firstStakeTime + i * INTEREST_CYCLE)) / INTEREST_CYCLE;
            }
        }
        return interest;
    }


    ///////////////////////////////// admin function /////////////////////////////////
    event AdminWithdrawToken(address operator, address indexed tokenAddress, address indexed to, uint amount);

    /**
     * @dev adminWithdrawToken
     */
    function adminWithdrawToken(address _token, address _to, uint _amount) external onlyAdmin returns (bool) {
        IERC20(_token).safeTransfer(_to, _amount);

        emit AdminWithdrawToken(msg.sender, _token, _to, _amount);
        return true;
    }

}
