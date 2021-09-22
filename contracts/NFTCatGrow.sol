// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./INFT.sol";
import "./Random.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './DivToken.sol';
import './XYZConfig.sol';

contract NFTCatGrow is Random, DivToken, XYZConfig {
    using SafeMath for uint;

    ICat public catAddr;
    IERC20 public payToken;
    address public feeTo; // 分红池地址

    uint bornSeconds; // 怀孕周期

    uint public feedFee; // 喂食费用
    uint public speedFee; // 加速费用
    uint public feedInterval; // 喂食间隔

    // 喂食
    event Feed(address indexed _sender, uint indexed _tokenid, uint indexed _fee);
    // 加速
    event Speed(address indexed _sender, uint indexed _tokenid, uint indexed _fee);
    // 成熟
    event GrowUp(address indexed _sender, uint indexed _tokenid);

//    constructor(address _catAddr, address _payToken, address _feeTo, bool _product) DivToken(_payToken) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        payToken = IERC20(_payToken);
//        feeTo = _feeTo;
//    }

    function __NFTCatGrow_init(address _catAddr, address _payToken, address _feeTo, bool _product) public initializer {
        DivToken.__DivToken_init(_payToken);
        XYZConfig.__XYZConfig_init(_product);
        Random.__Random_init();
        catAddr = ICat(_catAddr);
        payToken = IERC20(_payToken);
        feeTo = _feeTo;
        bornSeconds = 10 days; // 怀孕周期
        feedFee = 5_0000 * 1e9; // 喂食费用
        speedFee = 10_0000 * 1e9; // 加速费用
        feedInterval = 1 days; // 喂食间隔
    }

    // 喂食
    function feed(uint _tokenId) external lock notPaused onlyExternal returns (bool) {
        ICat.TokenInfo memory t = catAddr.getTokenInfo(_tokenId);
        require(t.step == STEP_BABY, "t.step == STEP_BABY");
        // 判断当天是否已经喂食过
        require(t.feedTime - feedInterval < block.timestamp, "t.feedTime - 1 days < block.timestamp");
        // 是否主人
//        require(catAddr.ownerOf(_tokenId) == msg.sender, "t.owner == msg.sender");

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

        t.power = t.power.mul(110).div(100);
        // 到成年时间了 直接成年
        if (t.feedTime > t.endTime) {
            t.step = STEP_AUDLT;
            t.feedTime = 0;
            t.endTime = 0;

            emit GrowUp(msg.sender, _tokenId);
        }

        catAddr.updateOnlyBy(t.tokenId, t);

        emit Feed(msg.sender, t.tokenId, feedFee);

        return true;
    }

    // 加速
    function addSpeedTime(uint _tokenId, uint _days) external lock notPaused onlyExternal returns (bool) {
        ICat.TokenInfo memory t = catAddr.getTokenInfo(_tokenId);
        require(t.tokenId > 0, "t.tokenId > 0");
        require(t.step == STEP_BABY, "t.step == STEP_BABY");
        require(_days > 0 && _days < 8, "_days > 0 && _days < 8");

        // 是否主人
//        require(catAddr.ownerOf(_tokenId) == msg.sender, "t.owner == msg.sender");

        // 已到达生产 无需加速
        require(t.endTime > block.timestamp, "t.endTime > block.timestamp");

        // 扣除喂食费用
        payToken.transferFrom(msg.sender, feeTo, speedFee.mul(_days));

        // 修改生产时间
        t.endTime = t.endTime.sub(feedInterval.mul(_days));
        t.power = t.power.mul(110).div(100);

        // 到成年时间了 直接成年
        if (t.endTime <= block.timestamp) {
            t.step = STEP_AUDLT;
            t.endTime = 0;
            t.feedTime = 0;

            emit GrowUp(msg.sender, _tokenId);
        }
        catAddr.updateOnlyBy(t.tokenId, t);
        emit Speed(msg.sender, t.tokenId, speedFee);

        return true;
    }

    //--------------------------------------------------------------------------
    receive() external payable {
    }

    fallback() external {
    }
}
