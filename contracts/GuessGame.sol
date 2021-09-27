// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import './XYZConfig.sol';
import './IShop.sol';

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote)
        external
        view
        returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] memory _bases, string[] memory _quotes)
        external
        view
        returns (ReferenceData[] memory);
}

contract GuessGame is BaseUpgradeable, XYZConfig {
    IStdReference ref;
    uint256 public price;
    uint public endTime;
    IShop public shopAddr;

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct guessData {
        uint upCoin;  // 买张金额
        uint downCoin; // 买跌金额
        uint preVal; // 上期价格
        uint finalVal; // 最终价格
        uint totalAward;
        mapping(address => uint) up;  // 买涨玩家
        mapping(address => uint) down; // 买跌玩家
        mapping(address => bool) reward; // 奖励
    }

    mapping(uint => guessData) public gameData;
    uint public currentID;
    uint public accAward;

    mapping (address => EnumerableSet.UintSet) private myGuess; // 我参与的竞猜期数

    event GUESS(address indexed _sender, bool _up, uint _coin);
    event OPENREWARD(address indexed _sender, uint _val);
    event FETCH(address indexed _sender, uint _id, uint _reward);

//    constructor(address _ref, address _shopAddr, bool _product) XYZConfig(_product) {
//        ref = IStdReference(_ref);
//        shopAddr = IShop(_shopAddr);
//
//        price = getPrice();
//        endTime = block.timestamp + 300;
//        currentID = 1;
//        gameData[currentID].preVal = price;
//        auth[msg.sender] = true;
//    }

    function __GuessGame_init(address _ref, address _shopAddr, bool _product) public initializer {
        XYZConfig.__XYZConfig_init(_product);

        ref = IStdReference(_ref);
        shopAddr = IShop(_shopAddr);

        price = getPrice();
        endTime = block.timestamp + 300;
        currentID = 1;
        gameData[currentID].preVal = price;
        auth[msg.sender] = true;
    }

    function getPrice() internal view returns (uint256) {
        IStdReference.ReferenceData memory data = ref.getReferenceData("BNB","BUSD");
        return data.rate;
    }

    // 竞猜
    function guess(bool _up, uint _coin) external lock {
        require(block.timestamp < endTime, "block.timestamp < endTime");

        // 不能同时买涨跌
        if (_up) {
            require(gameData[currentID].down[msg.sender] == 0, "gameData[currentID].down[msg.sender] == 0");
        } else {
            require(gameData[currentID].up[msg.sender] == 0, "gameData[currentID].down[msg.sender] == 0");
        }

        // 扣费。。。
        shopAddr.delItem(msg.sender, catFood, _coin);

        guessData storage _d = gameData[currentID];
        if (_d.up[msg.sender] == 0 && _d.down[msg.sender] == 0) {
            // 第一次竞猜
            myGuess[msg.sender].add(currentID);
        }

        if (_up) {
            _d.up[msg.sender] = _d.up[msg.sender].add(_coin);
            _d.upCoin = _d.upCoin.add(_coin);
        } else {
            _d.down[msg.sender] = _d.down[msg.sender].add(_coin);
            _d.downCoin = _d.downCoin.add(_coin);
        }

        emit GUESS(msg.sender, _up, _coin);
    }

    // 开奖
    function openReward() external onlyAuth {
        price = getPrice();
        gameData[currentID].finalVal = price;

        if ((price > gameData[currentID].preVal && gameData[currentID].upCoin == 0) ||
            (price < gameData[currentID].preVal && gameData[currentID].downCoin == 0)) {
                // 没有人中 则累积到下一期
                accAward = accAward.add(gameData[currentID].upCoin).add(gameData[currentID].downCoin);
            } else if (price != gameData[currentID].preVal) {
                // 有人中了
                gameData[currentID].totalAward = accAward.add(gameData[currentID].upCoin).add(gameData[currentID].downCoin);
                accAward = 0;
            }

        currentID = currentID.add(1);
        // 生成新的数据
        gameData[currentID].preVal = price;
        endTime = block.timestamp + 300;

        emit OPENREWARD(msg.sender, price);
    }

    struct hisData {
        uint id; // 期数
        uint upCoin; // 看涨总数
        uint downCoin; // 看跌总数
        uint myUp; // 我买账的数量
        uint myDown; // 我买跌的数量
        uint preVal; // 上期价格
        uint finalVal; // 最终价格
        uint totalAward; // 最终奖池
        bool gotReward; //是否已领取奖励
    }

    function getHisData(uint i) internal view returns (hisData memory his) {
        his.id = i;
        his.upCoin = gameData[i].upCoin;
        his.downCoin = gameData[i].downCoin;
        his.myUp = gameData[i].up[msg.sender];
        his.myDown = gameData[i].down[msg.sender];
        his.preVal = gameData[i].preVal;
        his.finalVal = gameData[i].finalVal;
        his.gotReward = gameData[i].reward[msg.sender];
        his.totalAward = gameData[i].totalAward;
    }

    // 历史
    function his(uint _start, uint _end) external view returns(hisData[] memory) {
        require(_end < currentID, "_end < currentID");
        require(_end >= _start, "_end >= _start");

        hisData[] memory data = new hisData[](_end - _start + 1);
        for (uint i = _start; i < _end + 1; i++) {
            data[i - _start] = getHisData(i);
        }

        return data;
    }

    // 当前期  ID 结束时间  看涨总数  看跌总数
    function q() external view returns(uint, uint, uint, uint, uint, uint) {
        return (currentID, endTime, gameData[currentID].upCoin, gameData[currentID].downCoin,
            gameData[currentID].preVal, getPrice());
    }

    // 领取奖励
    function fetch(uint _id) external lock {
        guessData storage _d = gameData[_id];

        uint reward = 0;
        if (_d.preVal == _d.finalVal) {
            // 平  给玩家退钱
            reward = _d.up[msg.sender].add(_d.down[msg.sender]);
            shopAddr.addItem(msg.sender, catFood, reward);
        } else if (_d.preVal > _d.finalVal && _d.down[msg.sender] > 0) {
            // 跌
            reward = _d.down[msg.sender].mul(_d.totalAward).div(_d.downCoin);
            shopAddr.addItem(msg.sender, catFood, reward);
        } else if (_d.preVal < _d.finalVal && _d.up[msg.sender] > 0) {
            reward = _d.up[msg.sender].mul(_d.totalAward).div(_d.upCoin);
            shopAddr.addItem(msg.sender, catFood, reward);
        }

        _d.reward[msg.sender] = true;

        emit FETCH(msg.sender, _id, reward);
    }

    // 我的竞猜
    function myhis(uint _index, uint _offset) external view returns(hisData[] memory) {
        uint totalSize = myGuess[msg.sender].length();
        require(0 < totalSize && totalSize > _index, "getNFTs: 0 < totalSize && totalSize > _index");
        if (totalSize < _index + _offset) {
            _offset = totalSize - _index;
        }

        hisData[] memory data = new hisData[](_offset);
        for (uint i = 0; i < _offset; i++) {
            data[i] = getHisData(myGuess[msg.sender].at(_index + i));
        }

        return data;
    }
}
