// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "./Random.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './DivToken.sol';
import './XYZConfig.sol';

contract NFTCatBorn is Random, DivToken, XYZConfig {
    ICat public catAddr;
    IERC20 public payToken;
    address public feeTo; // 分红池地址

    struct BabyInfo {
        uint tokenId;
        uint grade;
        uint stype;
        uint sex;
        uint endTime;  // 到期时间
        uint initTime; // 初始时间
        uint feedTime; // 到期喂食时间
        address owner; // 拥有者
        uint monStype;     // 母亲类型
        uint monSex;       // 母亲
        uint16 monHp; // 母亲生命值
        uint16 monAtk; // 母亲攻击力
        uint16 monDef; // 母亲防御
    }

    using SafeMath for uint;
    using EnumerableSet for EnumerableSet.UintSet;

    // 各种等级猫可以怀孕的个数
    uint[] public pregnancyNum;
    // 怀孕概率
    uint[] public pregnancyRate;

    uint bornSeconds; // 怀孕周期

    uint public feedFee; // 喂食费用
    uint public speedFee; // 加速费用
    uint public feedInterval; // 喂食间隔

    // 增加生出母猫概率需要消耗的cp
    uint constant addPercent = 10;
    uint[] public femaleUseCP;

    mapping(uint => address) public _ownerOf;
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    mapping(uint => BabyInfo) public _tokenInfoOf;

    // 怀孕事件
    event Pregnancy(address indexed _sender, uint indexed _lv, uint _mother, bool _succ);
    // 喂食
    event Feed(address indexed _sender, uint indexed _tokenid, uint indexed _fee);
    // 加速
    event Speed(address indexed _sender, uint indexed _tokenid, uint indexed _fee);
    // 出生
    event Born(address indexed _sender, uint _tokenid, uint _babyId);

//    constructor(address _catAddr, address _payToken, address _feeTo, bool _product) DivToken(_payToken) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        payToken = IERC20(_payToken);
//        feeTo = _feeTo;
//    }

    function __NFTCatBorn_init(address _catAddr, address _payToken, address _feeTo, bool _product) public initializer {
        Random.__Random_init();
        DivToken.__DivToken_init(_payToken);
        XYZConfig.__XYZConfig_init(_product);
        catAddr = ICat(_catAddr);
        payToken = IERC20(_payToken);
        feeTo = _feeTo;
        pregnancyNum = [3000, 2000];
        pregnancyRate = [10, 20, 30, 40, 50];
        bornSeconds = 10 days; // 怀孕周期
        feedFee = 300 * 1e18; // 喂食费用
        speedFee = 800 * 1e18; // 加速费用
        feedInterval = 1 days; // 喂食间隔
        femaleUseCP = [1000 * 1e18, 2000 * 1e18];
    }

    function getBabyInfo(uint _tokenId) public view returns (BabyInfo memory) {
        // require(_tokenId <= _currentTokenId, "_tokenId <= _currentTokenId");
        return _tokenInfoOf[_tokenId];
    }

    function mintOnlyBy(address _to, uint _tokenId, BabyInfo memory _tokenInfo) internal returns (bool) {
        require(0 == _tokenInfoOf[_tokenId].tokenId, "0 == _tokenInfoOf[_tokenId].tokenId");
        _holderTokens[_to].add(_tokenId);
        _ownerOf[_tokenId] = _to;
        _tokenInfoOf[_tokenId] = _tokenInfo;

        return true;
    }

    // update only by auth account
    function updateOnlyBy(uint _tokenId, BabyInfo memory _tokenInfo) internal returns (bool) {
        _tokenInfoOf[_tokenId] = _tokenInfo;
    }

    /**
     * @dev burn only by auth account
     */
    function burnOnlyBy(address _owner, uint _tokenId) internal returns (bool) {
        if (0 != _tokenInfoOf[_tokenId].tokenId) {
            delete _tokenInfoOf[_tokenId];
        }

        _holderTokens[_owner].remove(_tokenId);
        delete _ownerOf[_tokenId];

        return true;
    }

    // 生成猫的性别
    function genSex(uint _rate) public returns(uint8) {
        uint _rand = rand100();
        if (_rand < _rate) {
            return FEMALE;
        }
        return MALE;
    }

    function genBaby(address _addr, uint _tokenId, uint _stype, uint _sex, ICat.TokenInfo memory mon) internal view returns (BabyInfo memory t) {
        t.tokenId = _tokenId;
        t.endTime = block.timestamp + bornSeconds;
        t.owner = _addr;
        t.grade = mon.grade;
        t.stype = _stype;
        t.sex = _sex;
        t.feedTime = block.timestamp + feedInterval;
        t.initTime = block.timestamp;
        t.monStype = mon.stype;
        t.monSex = mon.sex;
        t.monHp = mon.hp;
        t.monAtk = mon.atk;
        t.monDef = mon.def;
    }

    // 怀孕
    function pregnancy(uint _mother, uint _rate, uint _femaleRate) external payable notPaused onlyExternal returns (bool) {
        require(_rate > 0 && _rate < 6, "_rate > 0 && _rate < 6");
        require(_femaleRate >= 0 && _femaleRate < 6, "_femaleRate >= 0 && _femaleRate < 6");

        // 判断妈妈是否存在 是否是母猫 是否是主人
        ICat.TokenInfo memory mon = catAddr.getTokenInfo(_mother);
        require(mon.sex == FEMALE, "mon.sex == FEMALE");
        require(msg.sender == catAddr.ownerOf(_mother), "msg.sender == catAddr.ownerOf(_mother)");

        // 判断是否有哺乳期的猫
        BabyInfo memory baby = getBabyInfo(_mother);
        require(baby.tokenId == 0, "baby.tokenId == 0");

        // 只有34两个等级的猫才可以生
        require(mon.grade > 2 && mon.grade < 5, "_lv > 0 && _lv < 3");
        require(pregnancyNum[mon.grade - 3] > 0, "pregnancyNum[grade] > 0");

        // 只有成年母猫才可以
        require(mon.step == STEP_AUDLT, "mon.step == STEP_AUDLT");

        require(pregnancyFee[mon.grade - 3][_rate - 1] <= msg.value, "bnb not enough");
        DivToPeopleEth(msg.value);

        // 增加生出母猫概率
        uint femaleRate = female_cat_rate;
        if (_femaleRate > 0) {
            femaleRate = female_cat_rate + _femaleRate * addPercent;
            // 扣除费用
            payToken.transferFrom(msg.sender, feeTo, femaleUseCP[mon.grade - 3] * _femaleRate);
        }

        // 判断怀孕概率
        uint _rand = rand100();
        if (pregnancyRate[_rate - 1] > _rand) {// 怀孕成功
            // 把母猫转移到猫咪地址
            catAddr.safeTransferFrom(msg.sender, address(this), _mother);

            // 生成孕期小猫数据
            uint _sex = genSex(femaleRate);
            uint _stype;
            if (mon.grade == 1) {
                _stype = uint8(rand_weight(cat_stype_rate1)); // 随机猫属于哪个系列
            } else if (mon.grade == 2) {
                _stype = uint8(rand_weight(cat_stype_rate2));
            } else if (mon.grade == 3) {
                _stype = uint8(rand_weight(cat_stype_rate3));
            } else {
                _stype = 0;
            }

            BabyInfo memory c = genBaby(msg.sender, _mother, _stype, _sex, mon);
            mintOnlyBy(msg.sender, _mother, c);

            // 修改可生育小猫数据
            pregnancyNum[mon.grade - 3] = pregnancyNum[mon.grade - 3].sub(1);
            emit Pregnancy(msg.sender, mon.grade, _mother, true);
            return true;
        } else {
            // 怀孕失败
            emit Pregnancy(msg.sender, mon.grade, _mother, false);
            return false;
        }
    }

    // 喂食
    function feed(uint _tokenId) external lock notPaused onlyExternal returns (bool) {
        BabyInfo memory t = getBabyInfo(_tokenId);

        // 判断当天是否已经喂食过
        require(t.feedTime - feedInterval < block.timestamp, "t.feedTime - 1 days < block.timestamp");
        // 是否主人
        require(t.owner == msg.sender, "t.owner == msg.sender");

        // 扣除喂食费用
        payToken.transferFrom(msg.sender, feeTo, feedFee);

        if (t.feedTime > block.timestamp) { //未超时喂食
            // 修改下次喂食截至时间
            t.feedTime = t.feedTime.add(feedInterval);
        } else {// 超时喂食
            uint delay = block.timestamp.sub(t.feedTime);
            t.feedTime = t.feedTime.add(feedInterval).add(delay);
            t.endTime = t.endTime.add(delay);
        }

        updateOnlyBy(t.tokenId, t);

        emit Feed(msg.sender, t.tokenId, feedFee);

        return true;
    }

    // 加速
    function addSpeedTime(uint _tokenId, uint _days) external lock notPaused onlyExternal returns (bool) {
        BabyInfo memory t = getBabyInfo(_tokenId);
        require(t.tokenId > 0, "t.tokenId > 0");
        require(_days > 0 && _days < 8, "_days > 0 && _days < 8");

        // 是否主人
        require(t.owner == msg.sender, "t.owner == msg.sender");
        // 已到达生产 无需加速
        require(t.endTime > block.timestamp, "t.endTime > block.timestamp");

        // 扣除喂食费用
        payToken.transferFrom(msg.sender, feeTo, speedFee.mul(_days));

        // 修改生产时间
        t.endTime = t.endTime.sub(feedInterval.mul(_days));
        updateOnlyBy(t.tokenId, t);

        emit Speed(msg.sender, t.tokenId, speedFee);

        return true;
    }

    // 生育
    function born(uint _tokenId) external lock notPaused onlyExternal returns (bool) {
        BabyInfo memory t = getBabyInfo(_tokenId);
        // 是否主人
        require(t.owner == msg.sender, "t.owner == msg.sender");
        // 是否已经到期
        require(t.endTime < block.timestamp, "t.endTime < block.timestamp");
        // 当天是否喂食
//        require(t.feedTime >= t.endTime, "t.feedTime - feedInterval >= t.endTime");

        // 销毁孕育小猫数据
        burnOnlyBy(t.owner, _tokenId);

        // 把母猫给转回去
        catAddr.safeTransferFrom(address(this), msg.sender, _tokenId);

        // 生出小猫
        ICat.TokenInfo memory ti = genCat(t.grade, t.sex, t.stype);
        catAddr.mintOnlyBy(msg.sender, ti.tokenId, ti);

        emit Born(msg.sender, _tokenId, ti.tokenId);

        return true;
    }

    // 生成tokenid
    function genCatTokenId(uint _grade) public view returns(uint) {
        if (_grade < 4) {
            return catAddr.currentTokenId() + 1;
        } else {
            return catAddr.royalTokenId() + 1;
        }
    }

    // 生成一个cat结构数据
    function genCat(uint _grade, uint _sex, uint _type) internal view returns(ICat.TokenInfo memory ti) {
        ti.grade = uint8(_grade);
        ti.stype = uint8(_type);
        ti.sex = uint8(_sex);
        ti.tokenId = genCatTokenId(_grade);
        ti.endTime = block.timestamp + bornSeconds;
        ti.feedTime = block.timestamp + feedInterval;
        ti.initTime = block.timestamp;
        ti.step = STEP_BABY;
        ti.power = basePower[ti.grade - 1];
        ti.initPower = basePower[ti.grade - 1];

        return ti;
    }

    function list() external view returns(BabyInfo[] memory _nftcats) {
        uint len = _holderTokens[msg.sender].length();
        _nftcats = new BabyInfo[](len);
        for (uint i = 0; i < len; i++) {
            _nftcats[i] = _tokenInfoOf[_holderTokens[msg.sender].at(i)];
        }
    }

    //--------------------------------------------------------------------------
    receive() external payable {
    }

    fallback() external {
    }
}
