// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "./Random.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import './XYZConfig.sol';
import "hardhat/console.sol";

contract ExchangeDivToken is BaseUpgradeable {
    using SafeMath for uint;

    mapping(uint => address)    public PeopleAddressOf;     // index => People address
    mapping(uint => uint)       public PeoplePer10000Of;    // People address => per100

    uint public PeopleCount;

    // todo
    function IniPeople() internal {
        // 编号	比例	地址
        PeopleAddressOf[1] = 0xC78be2f6a4bd79e098806Bb91343Ca11d885d1f6;
        PeoplePer10000Of[1] = 700;

        PeopleAddressOf[2] = 0x926e7ee0Eb81266f80d434805c88a4c0043a2D59;
        PeoplePer10000Of[2] = 600;

        PeopleAddressOf[3] = 0xd9eda60883ac4E880593E43047E3b1AAA331bd23;
        PeoplePer10000Of[3] = 5000;

        PeopleAddressOf[4] = 0x57659746d9c6942259C6b4f34189CBB7A4983932;
        PeoplePer10000Of[4] = 1000;

        PeopleAddressOf[5] = 0x0ef3EbC0CdF81c7fBC08B4Abd382F20F5Ec2Ef5A;
        PeoplePer10000Of[5] = 300;

        PeopleAddressOf[6] = 0x26e2bC1fd8F30aC51cF9D315c091d3a4e6d2672a;
        PeoplePer10000Of[6] = 200;

        PeopleAddressOf[7] = 0xd3d909f854ae4624c4E2f4EB45F43EDcB132b8db;
        PeoplePer10000Of[7] = 500;

        PeopleAddressOf[8] = 0x3946d3712C5e9a7D01b1E4C6b484A799f01257d9;
        PeoplePer10000Of[8] = 200;

        PeopleAddressOf[9] = 0x6e81CAb335A40f3690F6ba86C3B18D95e107d2aC;
        PeoplePer10000Of[9] = 1500;

        PeopleCount = 9;

        uint _sum = 0;
        for(uint i = 1; i <= PeopleCount; i++) {
            _sum = _sum + PeoplePer10000Of[i];
        }
        require(_sum == 10000, "_sum == 10000");
    }

    // 兑换ETH收益分配：
    function DivToPeopleEth(uint _ethAmount) internal {
        for (uint i = 1; i <= PeopleCount; i++) {
            address people = PeopleAddressOf[i];
            uint Per10000 = PeoplePer10000Of[i];
            uint PeopleEthAmount = _ethAmount * Per10000 / 10000;
            payable(people).transfer(PeopleEthAmount);
        }
    }
}

contract NFTCatExchange is ExchangeDivToken, Random, XYZConfig {
    ICat public catAddr;
    ISlot public slotAddr;
    using SafeMath for uint;

    bool public isStart;

    // 可兑换到第几层
    uint8 public can_exchange_num;
    // 总共几层
    uint8 public layer_num;
    // 4个等级盲盒数量
    uint[4] public blind_box_num;
    // 已兑换的4个等级盲盒数量
    uint[4] public open_box_num;
    // 4个等级盲盒各自开出的不同等级猫的数量 todo
    uint[3][4] public blind_box_cat_num;
    // 4个等级盲盒各自已开出的不同等级猫数量
    uint[3][4] public open_box_cat_num;
    // 皇室猫的男女数量
    uint[2] public grade4_num;

    uint[] public giveSlotNum;
    uint constant giveSlotRate = 15;
    uint public restGiveSlotNum;

    uint bornSeconds; // 怀孕周期
    uint public feedInterval; // 喂食间隔

    uint[] public randValues;

    event ExchangeToken(address indexed _sender, uint indexed _lv, uint indexed _tokenid, uint _sex,
        uint _grade, uint _stype, uint _slotTokenId, uint _slotGrade, uint _slotStype);
    event AdminWithdrawToken(address indexed _sender, uint indexed _eth, uint indexed _cp);

//    constructor(address _catAddr, address _slotAddr, bool _production) XYZConfig(_production) {
//        catAddr = ICat(_catAddr);
//        slotAddr = ISlot(_slotAddr);
//        auth[msg.sender] = true;
//        IniPeople();
//    }

    function initialize(address _catAddr, address _slotAddr, bool _production) public initializer {
        BaseUpgradeable.__Base_init();
        Random.__Random_init();
        XYZConfig.__XYZConfig_init(_production);
        catAddr = ICat(_catAddr);
        slotAddr = ISlot(_slotAddr);
        auth[msg.sender] = true;
        IniPeople();
        isStart = false;
        can_exchange_num = 1;
        layer_num = 1;
        blind_box_num = [2000, 3000, 3000, 1890];
        open_box_num = [0, 0, 0, 0];
        blind_box_cat_num = [[1600, 380, 20], [1800, 1050, 150], [1200, 1200, 600], [1888, 1, 1]];
        open_box_cat_num = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
        giveSlotNum = [400, 400, 400];
        restGiveSlotNum = 1500;
        bornSeconds = 10 days;
        feedInterval = 1 days;
        randValues = [1,2,3,4,5,6,7,8,9,10];
        grade4_num = [0, 0];
    }

    function resetXYZConfig(bool _production) external onlyAdmin {
        XYZConfig.initConfig(_production);
    }

    function setIniPeople() external onlyAdmin {
        IniPeople();
    }

    // 设置兑换开启到底基层
    function setCanExchangeNum(uint8 _i) external notPaused onlyExternal returns (bool) {
        can_exchange_num = _i;
        isStart = true;
        return true;
    }

    // 设置开启状态
    function setExchangeState(bool _state) external notPaused onlyExternal returns (bool) {
        isStart = _state;
        return true;
    }

    // 生成猫的性别
    function genSex(uint _grade) internal returns(uint8) {
        if (_grade < 3 || _grade == 6) {
            return MALE;
        } else if (_grade == 5) {
            return FEMALE;
        } else {
            if (grade4_num[0] >= 1555 ) {
                return FEMALE;
            }

            if (grade4_num[1] >= 333 ) {
                return MALE;
            }

            uint _rand = rand100();
            if (_rand < female_cat_rate) {
                return FEMALE;
            }
            return MALE;
        }
    }

    // 生成tokenid
    function genTokenId(uint _grade) public view returns(uint) {
        if (_grade < 4) {
            return catAddr.currentTokenId() + 1;
        } else {
            return catAddr.royalTokenId() + 1;
        }
    }

    // 获取猫等级
    function getGrade(uint _lv) internal returns (uint) {
        // 高级盲盒 判断是否已经有猫王 猫后
        if (_lv == 4) {
            if (open_box_cat_num[3][2] == 0) {
                require(auth[msg.sender], "KING need auth");
                return 6; // 猫王
            } else if (open_box_cat_num[3][1] == 0) {
                require(auth[msg.sender], "QUEEN need auth");
                return 5; // 猫后
            }
            return 4; // 皇室猫
        } else {
            // 获取剩余可生成的猫数量
            uint[] memory _rest = new uint[](4);
            for(uint i = 0; i < 3; i++) {
                if (blind_box_cat_num[_lv - 1][i] >= open_box_cat_num[_lv - 1][i]) {
                    _rest[i] = blind_box_cat_num[_lv - 1][i] - open_box_cat_num[_lv - 1][i];
                } else {
                    _rest[i] = 0;
                }
            }
            return rand_weight(_rest) + 1;
        }
    }

    // 生成属性 生命值 攻击力 防御
    function genProperty(ICat.TokenInfo memory ti) internal {
        uint16 _rand = uint16(rand_list(randValues));
        if (ti.grade == 1) {
            ti.hp = 100 + _rand + ti.stype;
            ti.atk = 40 + _rand + ti.stype;
            ti.def = 10 + _rand + ti.stype;
        }
        if (ti.grade == 2) {
            ti.hp = 150 + _rand + ti.stype;
            ti.atk = 70 + _rand + ti.stype;
            ti.def = 30 + _rand + ti.stype;
        }
        if (ti.grade == 3) {
            ti.hp = 200 + _rand + ti.stype;
            ti.atk = 100 + _rand + ti.stype;
            ti.def = 50 + _rand + ti.stype;
        }
        if (ti.grade == 4) {
            ti.hp = 300 + _rand;
            ti.atk = 150 + _rand;
            ti.def = 70 + _rand;
        }
        if (ti.grade == 5) {
            ti.hp = 500;
            ti.atk = 200;
            ti.def = 105;
        }
        if (ti.grade == 6) {
            ti.hp = 500;
            ti.atk = 220;
            ti.def = 90;
        }
    }

    // 生成一个NFT结构数据
    function genNft(uint _lv) internal returns(ICat.TokenInfo memory ti) {
        // 根据盲盒等级 以及 当前盲盒剩下的猫随机出猫的等级
        uint grade = getGrade(_lv);
        ti.grade = uint8(grade);
        ti.sex = uint8(genSex(grade));
        if (_lv == 1) {
            ti.stype = uint8(rand_weight(cat_stype_rate1)); // 随机猫属于哪个系列
        } else if (_lv == 2) {
            ti.stype = uint8(rand_weight(cat_stype_rate2));
        } else if (_lv == 3) {
            ti.stype = uint8(rand_weight(cat_stype_rate3));
        } else {
            ti.stype = 0;
        }

        ti.tokenId = genTokenId(grade);
        ti.power = basePower[ti.grade - 1];
        ti.initPower = basePower[ti.grade - 1];

        // 猫王猫后直接成年
        if (grade == 5 || grade == 6) {
            ti.step = STEP_AUDLT;
        } else {
            ti.endTime = block.timestamp + bornSeconds;
            ti.feedTime = block.timestamp + feedInterval;
            ti.initTime = block.timestamp;
            ti.step = STEP_BABY;
        }

        // 生成属性值
        genProperty(ti);

        return ti;
    }

    // 系统首先直接兑换了猫王 猫后
    function exchangeCatKingAndQueen() external onlyAdmin returns (bool) {
        exchangeOneToken(address(msg.sender), 4);
        exchangeOneToken(address(msg.sender), 4);

        return true;
    }

    function genSlotStype(uint _grade, uint _stype) internal returns (uint _res){
        if (_grade < 4) {
            _res = rand100() % 4;
            if (_res == _stype) {
                _res = (_res + 1) % 4;
            }
        } else {
            _res = 0;
        }
    }

    // 生成一个Slot结构数据
    function genSlot(uint _stype) internal returns(ISlot.TokenInfo memory ti) {
        ti.grade = uint8(rand_weight(giveSlotNum) + 1);
        ti.stype = uint8(genSlotStype(ti.grade, _stype));
        ti.tokenId = slotAddr.currentTokenId() + 1;
    }

    // 兑换单个盲盒
    function exchangeOneToken(address _addr, uint _lv) internal returns (bool) {
        ICat.TokenInfo memory ti = genNft(_lv);
        // 修改已兑换数量
        uint _offset = 1;
        if (_lv == 4) {
            _offset = 4;
        }
        // 修改已经已经兑换出来的等级猫数量
        open_box_cat_num[_lv - 1][ti.grade - _offset] = open_box_cat_num[_lv - 1][ti.grade - _offset] + 1;
        // 修改盲盒兑换数量
        open_box_num[_lv - 1] = open_box_num[_lv - 1].add(1);
        if (ti.grade == 4) {
            // 修改皇室猫的男女数量
            grade4_num[ti.sex - 1] = grade4_num[ti.sex - 1].add(1);
        }

        catAddr.mintOnlyBy(_addr, ti.tokenId, ti);
        // 15% 判断是否可以赠送卡槽
        uint _rand = rand100();
        if (_rand < giveSlotRate && restGiveSlotNum > 0) {
            ISlot.TokenInfo memory tSlot = genSlot(ti.stype);
            slotAddr.mintOnlyBy(_addr, tSlot.tokenId, tSlot);
            restGiveSlotNum = restGiveSlotNum.sub(1);
            giveSlotNum[tSlot.grade - 1] = giveSlotNum[tSlot.grade - 1].sub(1);
            emit ExchangeToken(_addr, _lv, ti.tokenId, ti.sex, ti.grade, ti.stype, tSlot.tokenId, tSlot.grade, tSlot.stype);
        } else {
            emit ExchangeToken(_addr, _lv, ti.tokenId, ti.sex, ti.grade, ti.stype, 0, 0, 0);
        }

        return true;
    }

    function checkCanExchange(uint _lv) public view returns(uint, uint) {
        return (open_box_num[_lv - 1], blind_box_num[_lv - 1] / layer_num * can_exchange_num);
    }

    // 查询剩余盲盒数量
    function getBoxNum() public view returns (uint[4] memory) {
        uint[4] memory leftBoxNum;
        leftBoxNum[0] = (blind_box_num[0] / layer_num * can_exchange_num).sub(open_box_num[0]);
        leftBoxNum[1] = (blind_box_num[1] / layer_num * can_exchange_num).sub(open_box_num[1]);
        leftBoxNum[2] = (blind_box_num[2] / layer_num * can_exchange_num).sub(open_box_num[2]);
        leftBoxNum[3] = (blind_box_num[3] / layer_num * can_exchange_num).sub(open_box_num[3]);

        return leftBoxNum;
    }

    // 查询皇室猫的男女数量
    function grade4Num() public view returns (uint[2] memory) {
        return grade4_num;
    }

    // 兑换  1 2 3 4 总共4种盲盒兑换
    function exchangeToken(uint _num, uint _lv) external lock notPaused onlyExternal payable returns (bool) {
        // 必须猫王猫后已经被系统领取了才可以兑换
        require(catAddr.royalTokenId() > 0, "catAddr.royalTokenId() > 0");
        require(_num > 0 && _num < 100, "_num > 0 && _num < 100");
        require(_lv > 0 && _lv < 5, "_lv > 0 && _lv < 5");
        require(isStart, "need start exchange");

        // 皇室猫，每个地址最多抢购两只
        if (_lv == 4) {
            uint[2] memory owner34 = catAddr.getNFTsOf34(msg.sender);
            require(owner34[1] <= 2, "The royal cat is greater than 2");
        }

        uint256 _amount = msg.value;
        require(exchange_coin[_lv - 1].mul(_num) <= _amount, "bnb not enough");

        // 判断是否还有足够多的盲盒够兑换
        uint _rest_can_exchange = (blind_box_num[_lv - 1] / layer_num * can_exchange_num).sub(open_box_num[_lv - 1]);
        require(_rest_can_exchange >= _num, "exchange num not enough");

        for(uint i = 0; i < _num; i++) {
            exchangeOneToken(msg.sender, _lv);
        }

        // 分钱
        DivToPeopleEth(_amount);

        return true;
    }

    function list() external view returns(ICat.TokenInfo[] memory _nftcats) {
        _nftcats = catAddr.getNFTsOf(msg.sender);
    }

    // ----------------admin----------------------
    function adminWithdrawToken() external onlyAdmin returns (bool) {
        uint _eth = address(this).balance;

        if (_eth > 0) {payable(admin).transfer(_eth);}

        emit AdminWithdrawToken(msg.sender, _eth, 0);

        return true;
    }

    //--------------------------------------------------------------------------
    receive() external payable {
    }

    fallback() external {
    }
}
