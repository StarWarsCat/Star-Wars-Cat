// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "hardhat/console.sol";

// NFT接口 含质押 赎回 余额等
contract NFTWrapper is BaseUpgradeable {
    using SafeMath for uint;
    using EnumerableSet for EnumerableSet.UintSet;

    uint private _totalSupply;
    uint private _totalWeight;
    // todo: temporarily for test
    mapping (address => uint) public _weights;
    mapping (address => EnumerableSet.UintSet) _userTokenIds;
    mapping (uint => uint) public cat2slot;
    mapping (uint => uint) public slot2cat;

    IERC20 public bToken;
    ICat public nft;  // cat
    ISlot public nft2; // slot

//    constructor(address _nft, address _nft2, address _bToken) {
//        nft = ICat(_nft);
//        nft2 = ISlot(_nft2);
//        bToken = IERC20(_bToken);
//    }

    function __NFTWrapper_init(address _nft, address _nft2, address _bToken) public initializer {
        BaseUpgradeable.__Base_init();
        nft = ICat(_nft);
        nft2 = ISlot(_nft2);
        bToken = IERC20(_bToken);
    }

    /**
     * @dev set AToken address
     * @param _bToken AToken contract address
     */
    function setBToken(address _bToken) external onlyAdmin returns (bool) {
        bToken = IERC20(_bToken);
        return true;
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint) {
        return _userTokenIds[account].length();
    }

    function totalWeight() public view returns (uint) {
        return _totalWeight;
    }

    function weightOf(address account) public view returns (uint) {
        return _weights[account];
    }

    function myStakeList(address _owner) external view returns (ICat.TokenInfo[] memory _cats) {
        uint len = balanceOf(_owner);
        _cats = new ICat.TokenInfo[](len);
        for (uint i = 0; i < len; i++) {
            _cats[i] = nft.getTokenInfo(_userTokenIds[_owner].at(i));
        }
    }

    function stake(address _sender, uint[] memory _tokenIds, uint _weight) public virtual {
        for (uint i = 0; i < _tokenIds.length / 2; i++) {
            nft.safeTransferFrom(_sender, address(this), _tokenIds[i * 2]);
            nft2.safeTransferFrom(_sender, address(this), _tokenIds[i * 2 + 1]);

            _userTokenIds[_sender].add(_tokenIds[i * 2]);
            cat2slot[_tokenIds[i * 2]] = _tokenIds[i * 2 + 1];
            slot2cat[_tokenIds[i * 2 + 1]] = _tokenIds[i * 2];
        }

        _totalSupply = _totalSupply.add(_tokenIds.length / 2);
        _totalWeight = _totalWeight.add(_weight);
        _weights[_sender] = _weights[_sender].add(_weight);
    }

    function withdraw(address _sender, uint[] memory _tokenIds, uint _weight) public virtual {
        for (uint i = 0; i < _tokenIds.length / 2; i++) {
            require(_userTokenIds[_sender].contains(_tokenIds[i * 2]), "withdraw: not tokenId owner");
            require(cat2slot[_tokenIds[i * 2]] == _tokenIds[i * 2 + 1], "cat2slot[_tokenIds[i * 2]] == _tokenIds[i * 2 + 1]");
            nft.safeTransferFrom(address(this), _sender, _tokenIds[i * 2]);
            nft2.safeTransferFrom(address(this), _sender, _tokenIds[i * 2 + 1]);

            _userTokenIds[_sender].remove(_tokenIds[i * 2]);
            delete cat2slot[_tokenIds[i * 2]];
            delete slot2cat[_tokenIds[i * 2 + 1]];
        }

        _totalSupply = _totalSupply.sub(_tokenIds.length / 2);
        _totalWeight = _totalWeight.sub(_weight);
        _weights[_sender] = _weights[_sender].sub(_weight);
    }

    function updatePower(address _sender, uint _weight) public virtual {
        _totalWeight = _totalWeight.add(_weight);
        _weights[_sender] = _weights[_sender].add(_weight);
    }
}

contract NFTPool is NFTWrapper {
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
    uint constant POOL_LIFE_CYCLE = 300 days;
    // 矿池产出衰减期数
    uint constant CYCLE_TIMES = POOL_LIFE_CYCLE / INTEREST_CYCLE;

    uint constant DECIMALS = 10 ** 18;
    // mint BToken amount each week
    uint INTEREST_BASE_AMOUNT;
    uint INTEREST_RATE; // 千分比

    uint public startTime;
    uint public endTime;
    // time of the first user stake, pool live start at this time
    uint public firstStakeTime;
    // 上次更新每股收益时间
    uint public lastInterestUpdateTime;
    // 矿池累计每股派息
    uint public accInterestPer;

    mapping(address => UserInfo) users;

    mapping(address => uint[6][10]) public userActive; // 统计每种系列的猫数量 预留几个 [catStype1,catStype2,catStype3,catStype4,catNum,catPower]

    event Stake(address indexed user, uint[] _tokenids);
    event Withdraw(address indexed user, uint[] _tokenids);
    event WithdrawReward(address indexed user, uint reward);
    event SetStartTime(address indexed _admin, uint _startTime);
    event SetEndTime(address indexed _admin, uint _endTime);

//    constructor(address _nft, address _nft2, address _bToken) NFTWrapper(_nft, _nft2, _bToken) {}

    function __NFTPool_init(address _nft, address _nft2, address _bToken) public initializer {
        NFTWrapper.__NFTWrapper_init(_nft, _nft2, _bToken);
        INTEREST_BASE_AMOUNT = 102400 * DECIMALS;
        INTEREST_RATE = 800;
        startTime = type(uint).max;
        endTime = type(uint).max;
        firstStakeTime = 0;
        lastInterestUpdateTime = 0;
        accInterestPer = 0;
    }

    function getUserActive(address _sender) public view returns(uint[6][10] memory) {
        return userActive[_sender];
    }

    function setUserActive(address _sender, uint[6][10] memory _data) external onlyAuth notPaused {
        userActive[_sender] = _data;
    }

    modifier checkStart() {
        require(block.timestamp > startTime, "block.timestamp > startTime");
        _;
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
        console.log(block.timestamp, _startTime);
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

    function stake(address _sender, uint[] memory _tokenIds, uint _weight) public onlyAuth override lock checkStart {
        require(endTime > block.timestamp, "stake: endTime > block.timestamp");
        require(0 < _tokenIds.length && _tokenIds.length <= 100, "stake: 0 < _tokenIds.length && _tokenIds.length <= 100");

        // update firstStakeTime & endTime at the first user stake
        if (0 == firstStakeTime) {
            firstStakeTime = block.timestamp;
            endTime = firstStakeTime + POOL_LIFE_CYCLE;
        }
        // 更新矿池累计每股派息和用户利息
        updateInterest(_sender);

        super.stake(_sender, _tokenIds, _weight);

        emit Stake(_sender, _tokenIds);
    }

    function withdraw(address _sender, uint[] memory _tokenIds, uint _weight) public override lock checkStart {
        require(balanceOf(_sender) > 0 , "withdraw: balanceOf(_sender) > 0");
        require(0 < _tokenIds.length && _tokenIds.length <= 100, "withdraw: exceed _tokenIds.length limit");

        // 更新矿池累计每股派息和用户利息
        updateInterest(_sender);

        super.withdraw(_sender, _tokenIds, _weight);

        emit Withdraw(_sender, _tokenIds);
    }

    function withdrawReward() public checkStart {
        // 更新矿池累计每股派息和用户利息
        address _sender = msg.sender;
        updateInterest(_sender);

        uint userInterest = users[_sender].accInterest;
        if (userInterest > 0) {
            users[_sender].accInterest = 0;
            users[_sender].withdrawnAmount = users[_sender].withdrawnAmount.add(userInterest);
            IERC20(bToken).transfer(_sender, userInterest);

            emit WithdrawReward(_sender, userInterest);
        }
    }

    // 返回我的算力 产出速度 我的质押数 已领取奖励 待领取奖励
    function myPoolInfo() external view returns (uint[5] memory) {
        address _sender = msg.sender;
        uint speed = 0;
        uint currUserInterest = 0;

        if (0 == totalSupply()) {
            return [0, 0, 0, users[_sender].withdrawnAmount, users[msg.sender].accInterest];
        }

        uint bTokenPerSecond = calculateInterest(block.timestamp - 1, block.timestamp);

        if (weightOf(_sender) > 0 && totalWeight() > 0) {
            speed = bTokenPerSecond.mul(weightOf(_sender)).div(totalWeight());
        }

        // current accumulating interest from lastInterestUpdateTime to now
        uint currAccInterest = calculateInterest(lastInterestUpdateTime, block.timestamp);

        if (totalWeight() > 0) {
            uint currAccInterestPer = accInterestPer.add(currAccInterest.mul(DECIMALS).div(totalWeight()));

            // userInterest = user_stake_amount * (accInterestPer - user_preInterestPer)
            uint userInterest = weightOf(_sender).mul(currAccInterestPer.sub(users[_sender].preInterestPer)).div(DECIMALS);
            currUserInterest = users[_sender].accInterest.add(userInterest);
        }

        return [weightOf(_sender), speed, balanceOf(_sender), users[_sender].withdrawnAmount, currUserInterest];
    }

    /**
     * @dev update accInterestPer & user interest
     * 更新矿池累计每股派息和用户利息
     */
    function updateInterest(address _sender) internal {
        // 1 >> update accInterestPer
        if (0 < totalWeight()) {
            // current accumulating interest from lastInterestUpdateTime to now
            uint currAccInterest = calculateInterest(lastInterestUpdateTime, block.timestamp);
            // update accInterestPer
            accInterestPer = accInterestPer.add(currAccInterest.mul(DECIMALS).div(totalWeight()));
            // update lastInterestUpdateTime
            lastInterestUpdateTime = block.timestamp;
        }

        // 2 >> update user interest
        // userInterest = user_stake_amount * (accInterestPer - user_preInterestPer)
        uint userInterest = weightOf(_sender).mul(accInterestPer.sub(users[_sender].preInterestPer)).div(DECIMALS);
        users[_sender].accInterest = users[_sender].accInterest.add(userInterest);
        // update user preInterestPer
        users[_sender].preInterestPer = accInterestPer;
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

    function updatePower(address _sender, uint _weight) public onlyAuth override {
        require(endTime > block.timestamp, "stake: endTime > block.timestamp");
        // update firstStakeTime & endTime at the first user stake
        if (0 == firstStakeTime) {
            firstStakeTime = block.timestamp;
            endTime = firstStakeTime + POOL_LIFE_CYCLE;
        }
        // 更新矿池累计每股派息和用户利息
        updateInterest(_sender);
        super.updatePower(_sender, _weight);
    }

    ///////////////////////////////// admin function /////////////////////////////////
    event AdminWithdrawNFT(address indexed _addr, address operator, address indexed to, uint indexed tokenId);
    event AdminWithdrawToken(address indexed _addr, address operator, address indexed to, uint amount);

    /**
     * @dev adminWithdrawNFT
     */
    function adminWithdrawNFT(address _addr, address _to, uint _tokenId) external onlyAdmin returns (bool) {
        IERC721(_addr).safeTransferFrom(address(this), _to, _tokenId);
        emit AdminWithdrawNFT(_addr, msg.sender, _to, _tokenId);
        return true;
    }

    /**
     * @dev adminWithdrawToken
     */
    function adminWithdrawToken(address _addr, address _to, uint _amount) external onlyAdmin returns (bool) {
        IERC20(_addr).transferFrom(_to, msg.sender, _amount);

        emit AdminWithdrawToken(_addr, msg.sender, _to, _amount);
        return true;
    }

}
