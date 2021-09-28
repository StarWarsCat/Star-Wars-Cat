// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "./Random.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './DivToken.sol';
import './XYZConfig.sol';

contract NFTSlotBuy is Random, DivToken, XYZConfig {
    ISlot public slotAddr;
    using SafeMath for uint;
    address public payToken;

    // struct TokenInfo {
    //     uint8 grade; // 1夏日猫 2未来猫 3电玩猫 4皇室猫 5猫后 6猫王
    //     uint8 stype; // grade为1-3的三种猫4个系列
    //     uint tokenId;
    // }

    uint[6] public buySlot_coin;
    uint[4] public slot_stype_rate;

    uint constant MONEY_TYPE_CP = 1;
    uint constant MONEY_TYPE_BNB = 2;

    event BuySlotToken(address indexed _sender, uint _lv, uint _tokenid, uint _stype);
    event AdminWithdrawToken(address indexed _sender, uint indexed _eth, uint indexed _cp);

//    constructor(address _nft, address _payToken, bool _production) DivToken(_payToken) XYZConfig(_production) {
//        slotAddr = ISlot(_nft);
//        auth[msg.sender] = true;
//        payToken = _payToken;
//    }

    function __NFTSlotBuy_init(address _nft, address _payToken, bool _production) public initializer {
        Random.__Random_init();
        DivToken.__DivToken_init(_payToken);
        XYZConfig.__XYZConfig_init(_production);
        slotAddr = ISlot(_nft);
        auth[msg.sender] = true;
        payToken = _payToken;

        buySlot_coin = [500 * 1e18, 1200 * 1e18, 4000 * 1e18, 10000 * 1e18, 50000 * 1e18, 50000 * 1e18];
        slot_stype_rate = [30, 20, 20, 30];
    }

    function setPayToken(address _payToken) external onlyAdmin {
        payToken = _payToken;
    }

    function setXYZConfig(bool _production) external onlyAdmin {
        XYZConfig.initConfig(_production);
    }

    // 生成一个NFT结构数据
    function genNft(uint _lv) internal returns(ISlot.TokenInfo memory ti) {
        // 根据盲盒等级 以及 当前盲盒剩下的猫随机出猫的等级
        uint grade = _lv;
        ti.grade = uint8(grade);

        if (_lv < 4) {
            uint[] memory rate = new uint[](4);
            for(uint i = 0; i < slot_stype_rate.length; i++) {
                rate[i] = slot_stype_rate[i];
            }
            ti.stype = uint8(rand_weight(rate)); // 随机属于哪个系列
        } else {
            ti.stype = 0;
        }

        ti.tokenId = slotAddr.currentTokenId() + 1;

        return ti;
    }

    function buyOneSlot(address _sender, uint _lv) internal returns(bool) {
        ISlot.TokenInfo memory ti = genNft(_lv);
        slotAddr.mintOnlyBy(_sender, ti.tokenId, ti);

        emit BuySlotToken(_sender, _lv, ti.tokenId, ti.stype);

        return true;
    }

    // 购买卡槽 _type 1cp购买 2bnb购买
    function buySlot(uint _num, uint _lv, uint _type) external lock notPaused onlyExternal payable returns (bool) {
        require(_num > 0 && _num < 100, "_num > 0 && _num < 100");
        require(_lv > 0 && _lv < 7, "_lv > 0 && _lv < 7");
        require(_type == MONEY_TYPE_CP || _type == MONEY_TYPE_BNB, "_type == MONEY_TYPE_CP || _type == MONEY_TYPE_BNB");

        if (_type == MONEY_TYPE_CP) {
            // 扣费cp
            uint256 _amount = buySlot_coin[_lv - 1].mul(_num);
            IERC20(payToken).transferFrom(msg.sender, address(this), _amount);
//            DivToPeopleCP(_amount);
        } else { //bnb购买
            uint256 _amount = msg.value;
            require(buySlot_bnb[_lv - 1].mul(_num) <= _amount, "bnb not enough");
            DivToPeopleEth(_amount);
        }

        for(uint i = 0; i < _num; i++) {
            buyOneSlot(msg.sender, _lv);
        }

        return true;
    }

    // 玩家卡槽列表
    function list() external view returns(ISlot.TokenInfo[] memory _slots) {
        _slots = slotAddr.getNFTsOf(msg.sender);
    }

    // ----------------admin----------------------
    // function adminWithdrawToken() external onlyAdmin returns (bool) {
    //     uint _eth = address(this).balance;
    //     uint _cp = IERC20(payToken).balanceOf(address(this));
    //
    //     if (_eth > 0) {payable(admin).transfer(_eth);}
    //     if (_cp > 0) {IERC20(payToken).transfer(admin, _cp);}
    //
    //     emit AdminWithdrawToken(msg.sender, _eth, _cp);
    //
    //     return true;
    // }
}
