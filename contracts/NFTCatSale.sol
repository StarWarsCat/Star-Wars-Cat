// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./INFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './DivToken.sol';

contract NFTCatSale is DivToken {
    ICat public catAddr;
    IGoods public goodsAddr;
    IERC20 public payToken;
    address public feeTo; // 分红池地址

    uint constant PRICE_TYPE_BNB = 1;
    uint constant PRICE_TYPE_CP = 2;

    uint constant OFF_GOODS_FEE = 1_0000 * 1e18; // 下架手续费
    uint constant SALE_SUCC_TAX = 5; // 交易成功手续费
    uint constant delayCheckTime = 10 minutes;

    using SafeMath for uint;

    event SaleCat(address indexed _sender, uint indexed _tokenId, uint indexed _id, uint _grade, uint _stype, uint _sex,
        uint _price, uint _type, uint _minPrice, uint _saleDuration, uint _delayDuration, uint _step, uint _hp, uint _atk, uint _def);
    event BuyCat(address indexed _sender, uint indexed _id, uint indexed _tokenId, uint _price, uint _endTime, bool _delay);
    event WithdrawCat(address indexed _sender, uint indexed _id, uint indexed _tokenId, uint _tax, uint _money);
    event AdminWithdrawToken(address indexed _sender, uint indexed _eth, uint indexed _cp);

//    constructor(address _catAddr, address _payToken, address _goodsAddr, address _feeTo) DivToken(_payToken) {
//        catAddr = ICat(_catAddr);
//        payToken = IERC20(_payToken);
//        goodsAddr = IGoods(_goodsAddr);
//        feeTo = _feeTo;
//    }

    function __NFTCatSale_init(address _catAddr, address _payToken, address _goodsAddr, address _feeTo) public initializer {
        DivToken.__DivToken_init(_payToken);
        catAddr = ICat(_catAddr);
        payToken = IERC20(_payToken);
        goodsAddr = IGoods(_goodsAddr);
        feeTo = _feeTo;
    }

    function genGoods(ICat.TokenInfo memory _tokenInfo, uint _type, uint _price, uint _saleDuration, uint _delayDuration,
        uint _minPriceAmount) internal view returns (IGoods.TokenInfo memory t) {
        t.id = goodsAddr.currentTokenId() + 1;
        t.tokenId = _tokenInfo.tokenId;
        t.grade = _tokenInfo.grade;
        t.stype = _tokenInfo.stype;
        t.sex = _tokenInfo.sex;
        t.priceType = _type;
        t.initialPrice = _price;
        t.price = _price;
        t.initialTime = block.timestamp;
        t.endTime = 0;
        t.lastPriceTime = block.timestamp;
        t.saleDuration = _saleDuration;
        t.delayDuration = _delayDuration;
        t.minPriceAmount = _minPriceAmount;
        t.initialOwner = msg.sender;
        t.owner = msg.sender;
        t.delayStart = false;
        t.step = _tokenInfo.step;
        t.hp = _tokenInfo.hp;
        t.atk = _tokenInfo.atk;
        t.def = _tokenInfo.def;
    }

    // 上架猫  1BNB拍卖  2CP拍卖
    function saleCat(uint _tokenId, uint _type, uint _price, uint _minPriceAmount, uint _saleDuration, uint _delayDuration) external notPaused returns (bool) {
        require(_type == PRICE_TYPE_BNB || _type == PRICE_TYPE_CP, "_type == 1 || _type == 2");
        require(0 <= _minPriceAmount, "0 <= _minPriceAmount");
        require(_saleDuration >= 0, "_priceDuration >= 0");
        require(_delayDuration < 86400, "_delayDuration < 86400");
        require(_saleDuration >= _delayDuration, "_saleDuration >= _delayDuration");

        catAddr.safeTransferFrom(msg.sender, address(goodsAddr), _tokenId);

        // get nft info
        ICat.TokenInfo memory tokenInfo = catAddr.getTokenInfo(_tokenId);
        IGoods.TokenInfo memory goods = genGoods(tokenInfo, _type, _price, _saleDuration, _delayDuration, _minPriceAmount);

        goodsAddr.add(msg.sender, goods.id, goods);

        emit SaleCat(msg.sender, _tokenId, goods.id, goods.grade, goods.stype, goods.sex, _price, _type, _minPriceAmount, _saleDuration, _delayDuration, goods.step, goods.hp, goods.atk, goods.def);

        return true;
    }

    // 竞拍
    function buyCat(uint _goodsId, uint _price) external notPaused onlyExternal payable returns (bool) {
        IGoods.TokenInfo memory goods = goodsAddr.getTokenInfo(_goodsId);
        // 判断商品是否存在
        require(goods.tokenId > 0, "goods.tokenId > 0");
        // 是否是主人或者刚竞拍过
        require(goods.initialOwner != msg.sender || goods.owner != msg.sender, "owner or initialOwner");
        // 判断金额是否超过最小加价
        require(_price >= goods.price.add(goods.minPriceAmount), "_price >= goods.price.add(goods.minPriceAmount)");
        // 不能超时间
        require(goods.endTime > block.timestamp || goods.endTime == 0, "out of time");

        // 如果是bnb 判断转账金额是否足够
        if (goods.priceType == PRICE_TYPE_BNB) {
            require(msg.value >= _price, "msg.value >= _price");
        }

        if (goods.saleDuration > 0) { // 竞拍
            // 需要把上一个竞拍方的钱退回去
            if (goods.initialOwner != goods.owner) {
                if (goods.priceType == PRICE_TYPE_BNB) {
                    require(goods.price <= address(this).balance, "goods.price == address(this).balance");
                    payable(goods.owner).transfer(goods.price);
                } else {
                    payToken.transfer(goods.owner, goods.price);
                }
            }

            // 扣玩家本次竞拍的钱
            if (goods.priceType != PRICE_TYPE_BNB) {
                payToken.transferFrom(msg.sender, address(this), _price);
            }

            // 记录玩家竞拍信息
            if (goods.initialOwner == goods.owner) { //第一次竞拍 修改竞拍结束时间
                goods.endTime = block.timestamp + goods.saleDuration;
            } else {// 已经有人竞拍过了
                // 判断是否需要启动延时周期
                if (!goods.delayStart && goods.endTime - block.timestamp < delayCheckTime) {
                    goods.delayStart = true;
                }
                if (goods.delayStart) { // 启动延时周期
                    goods.endTime = block.timestamp + goods.delayDuration;
                }
            }
            goods.owner = msg.sender;
            goods.price = _price;
            goodsAddr.update(_goodsId, goods);

            emit BuyCat(msg.sender, goods.id, goods.tokenId, _price, goods.endTime, goods.delayStart);
        } else { // 一口价
            // 把钱转给玩家
            uint tax = goods.price.mul(SALE_SUCC_TAX).div(100);
            uint finalprice = goods.price.sub(tax);

            if (goods.priceType == PRICE_TYPE_BNB) {
                require(goods.price <= address(this).balance, "_price == address(this).balance");
                payable(goods.initialOwner).transfer(finalprice);
                payable(feeTo).transfer(tax);
            } else {
                payToken.transferFrom(msg.sender, goods.initialOwner, finalprice);
                payToken.transferFrom(msg.sender, feeTo, tax);
            }

            goodsAddr.catTransfer(msg.sender, goods.tokenId);
            goodsAddr.remove(_goodsId);

            // 需要记录一条竞拍日志
            emit BuyCat(msg.sender, goods.id, goods.tokenId, _price, block.timestamp, false);
            // 记录领取事件
            emit WithdrawCat(msg.sender, goods.id, goods.tokenId, tax, finalprice);
        }

        return true;
    }

    // 下架
    function withdrawCat(uint _goodsId) external notPaused onlyExternal returns (bool) {
        IGoods.TokenInfo memory goods = goodsAddr.getTokenInfo(_goodsId);
        // 判断商品是否存在
        require(goods.tokenId > 0, "goods.tokenId > 0");

        if (goods.initialOwner == goods.owner) { // 没有人竞拍
            require(msg.sender == goods.initialOwner, "msg.sender == goods.initialOwner");
            // 收取下架手续费
//            payToken.transferFrom(msg.sender, feeTo, OFF_GOODS_FEE);
            // 把猫还给用户
            goodsAddr.catTransfer(msg.sender, goods.tokenId);

            emit WithdrawCat(msg.sender, goods.id, goods.tokenId, 0, 0);
        } else {
            require(goods.saleDuration > 0, "goods.isAuction"); // 竞拍的才走这里
            // 判断是否已经超时间了
            require(goods.endTime < block.timestamp, "wait endtime");

            // 拍卖成功 把钱转给买家 需要扣除手续费
            uint tax = goods.price.mul(SALE_SUCC_TAX).div(100);
            uint finalprice = goods.price.sub(tax);
            if (goods.priceType == PRICE_TYPE_BNB) {
                require(finalprice + tax <= address(this).balance, "finalprice + tax == address(this).balance");
                payable(goods.initialOwner).transfer(finalprice);
                payable(feeTo).transfer(tax);
                DivToPeopleEth(tax);
            } else {
                payToken.transfer(goods.initialOwner, finalprice);
                payToken.transfer(feeTo, tax);
//                DivToPeopleCP(tax);
            }

            // 把猫给买家
            goodsAddr.catTransfer(goods.owner, goods.tokenId);

            emit WithdrawCat(msg.sender, goods.id, goods.tokenId, tax, finalprice);
        }

        goodsAddr.remove(_goodsId);

        return true;
    }

    receive() external payable {
    }

    // ----------------admin----------------------
    function adminWithdrawToken() external onlyAdmin returns (bool) {
        uint _eth = address(this).balance;
        uint _cp = payToken.balanceOf(address(this));

        if (_eth > 0) {payable(admin).transfer(_eth);}
        if (_cp > 0) {payToken.transfer(admin, _cp);}

        emit AdminWithdrawToken(msg.sender, _eth, _cp);

        return true;
    }
}
