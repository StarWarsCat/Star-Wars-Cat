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
import "hardhat/console.sol";

interface IPool {
    function stake(address _sender, uint[] memory _tokenIds, uint _weight) external;
    function withdraw(address _sender, uint[] memory _tokenIds, uint _weight) external;
    function cat2slot(uint _catId) external returns(uint);
    function myStakeList(address _owner) external view returns (ICat.TokenInfo[] memory _cats);
    function getUserActive(address _sender) external view returns(uint[6][10] memory);
    function setUserActive(address _sender, uint[6][10] memory _data) external;
    function updatePower(address _sender, uint _weight) external;
}

contract NFTCatGrow is Random, DivToken, XYZConfig {
    using SafeMath for uint;

    ICat public catAddr;
    IERC20 public payToken;
    IPool public pool;
    address public feeTo; // 分红池地址
    address public poolAddr; // 质押池地址

    uint bornSeconds; // 怀孕周期

    uint public feedFee; // 喂食费用
    uint public speedFee; // 加速费用
    uint public feedInterval; // 喂食间隔

    // 喂食
    event Feed(address _sender, uint[] _tokenIds, uint _fee);
    // 加速
    event Speed(address _sender, uint[] _tokenIds, uint _fee);
    // 成熟
    event GrowUp(address _sender, uint _tokenid);

//    constructor(address _catAddr, address _payToken, address _feeTo, bool _product) DivToken(_payToken) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        payToken = IERC20(_payToken);
//        feeTo = _feeTo;
//    }

    function __NFTCatGrow_init(address _catAddr, address _payToken, address _feeTo, address _poolAddr, bool _product) public initializer {
        DivToken.__DivToken_init(_payToken);
        XYZConfig.__XYZConfig_init(_product);
        Random.__Random_init();
        catAddr = ICat(_catAddr);
        payToken = IERC20(_payToken);
        feeTo = _feeTo;
        poolAddr = _poolAddr;
        bornSeconds = 10 days; // 怀孕周期
        feedFee = 300 * 1e18; // 喂食费用
        speedFee = 800 * 1e18; // 加速费用
        feedInterval = 1 days; // 喂食间隔
        pool = IPool(_poolAddr);
    }

    // 增加质押中的算力
    function checkPower(uint grade, uint stype, uint power) internal {
        uint[6][10] memory activeData = pool.getUserActive(msg.sender);
        activeData = addActiveData(activeData, grade, stype, power);
        uint allPower = calcPower(activeData);  // 加成后算力
        pool.updatePower(msg.sender, allPower.sub(activeData[0][5]));
        activeData[0][5] = allPower;
        pool.setUserActive(msg.sender, activeData);
    }

    // 更新质押中的算力
    function addActiveData(uint[6][10] memory _data, uint _grade, uint _stype, uint _power) internal pure returns(uint[6][10] memory) {
        _data[_grade][5] = _data[_grade][5].add(_power);
        return _data;
    }

    // 计算加成算力
    function calcPower(uint[6][10] memory _data) public view returns(uint) {
        uint[10] memory powers;
        uint allPower = 0;

        // 计算每个系列集卡加成
        for (uint8 i = 1; i < 10; i++) {
            uint addPercent = 0;
            if (_data[i][0] > 0 && _data[i][1] > 0 && _data[i][2] > 0 && _data[i][3] > 0) {
                if (i <= 3) {
                    addPercent = addPercent.add(addGradePowerPercent[i]);
                }
            }
            // 皇室猫只需集成两只即可
            if (i == 4 && _data[i][4] >= 2) {
                addPercent = addPercent.add(addGradePowerPercent[i]);
            }

            powers[i] = _data[i][5].mul(10000 + addPercent).div(10000);
        }

        for (uint8 i = 1; i < 10; i++) {
            allPower = allPower.add(powers[i]);
        }

        return allPower;
    }

    // 喂食
    function feed(uint[] memory _tokenIds) external lock notPaused onlyExternal returns (bool) {
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint _tokenId = _tokenIds[i];

            ICat.TokenInfo memory t = catAddr.getTokenInfo(_tokenId);
            require(t.step == STEP_BABY, "t.step == STEP_BABY");
            // 判断当天是否已经喂食过
            require(t.feedTime - feedInterval < block.timestamp, "t.feedTime - 1 days < block.timestamp");

            // 在质押中也可以加速
            if (catAddr.ownerOf(_tokenId) != poolAddr) {
                // 是否主人
                require(catAddr.ownerOf(_tokenId) == msg.sender, "t.owner == msg.sender");
            }

            if (t.feedTime > block.timestamp) { //未超时喂食
                // 修改下次喂食截至时间
                t.feedTime = t.feedTime.add(feedInterval);
            } else {// 超时喂食
                uint delay = block.timestamp.sub(t.feedTime);
                t.feedTime = t.feedTime.add(feedInterval).add(delay);
                t.endTime = t.endTime.add(delay);
            }

            // 计算倍数
            uint rate = t.power.div(t.initPower) + 1;
            if (rate > 10) {
                rate = 10;
            }

            // 给质押中的增加算力
            if (catAddr.ownerOf(_tokenId) == poolAddr) {
                uint addPower = 0;
                if (t.feedTime > t.endTime) {
                    addPower = t.initPower.mul(11) - t.power;
                } else {
                    addPower = t.initPower.mul(rate) - t.power;
                }
                checkPower(t.grade, t.stype, addPower);
            }

            // 到成年时间了 直接成年
            if (t.feedTime > t.endTime) {
                t.step = STEP_AUDLT;
                t.feedTime = 0;
                t.endTime = 0;
                t.power = t.initPower.mul(11);

                emit GrowUp(msg.sender, _tokenId);
            }

            t.power = t.initPower.mul(rate);

            catAddr.updateOnlyBy(t.tokenId, t);

        }

        // 扣除喂食费用
        payToken.transferFrom(msg.sender, feeTo, feedFee.mul(_tokenIds.length));

        emit Feed(msg.sender, _tokenIds, feedFee.mul(_tokenIds.length));

        return true;
    }

    // 加速
    function addSpeedTime(uint[] memory _tokenIds, uint _days) external lock notPaused onlyExternal returns (bool) {
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint _tokenId = _tokenIds[i];
            ICat.TokenInfo memory t = catAddr.getTokenInfo(_tokenId);
            require(t.tokenId > 0, "t.tokenId > 0");
            require(t.step == STEP_BABY, "t.step == STEP_BABY");
            require(_days > 0 && _days < 8, "_days > 0 && _days < 8");

            // 在质押中也可以加速
            if (catAddr.ownerOf(_tokenId) != poolAddr) {
                // 是否主人
                require(catAddr.ownerOf(_tokenId) == msg.sender, "t.owner == msg.sender");
            }

            // 已到达生产 无需加速
            require(t.endTime > block.timestamp, "t.endTime > block.timestamp");

            // 计算倍数
            uint rate = t.power.div(t.initPower) + _days;
            if (rate > 10) {
                rate = 10;
            }

            // 修改生产时间
            t.endTime = t.endTime.sub(feedInterval.mul(_days));

            // 给质押中的增加算力
            if (catAddr.ownerOf(_tokenId) == poolAddr) {
                uint addPower = 0;
                if (t.endTime <= block.timestamp) {
                    addPower = t.initPower.mul(11) - t.power;
                } else {
                    addPower = t.initPower.mul(rate) - t.power;
                }
                checkPower(t.grade, t.stype, addPower);
            }

            // 到成年时间了 直接成年
            if (t.endTime <= block.timestamp) {
                t.step = STEP_AUDLT;
                t.endTime = 0;
                t.feedTime = 0;
                t.power = t.initPower.mul(11);

                emit GrowUp(msg.sender, _tokenId);
            }

            t.power = t.initPower.mul(rate);

            catAddr.updateOnlyBy(t.tokenId, t);
        }

        // 扣除喂食费用
        payToken.transferFrom(msg.sender, feeTo, speedFee.mul(_days).mul(_tokenIds.length));

        emit Speed(msg.sender, _tokenIds, speedFee.mul(_days).mul(_tokenIds.length));

        return true;
    }

    //--------------------------------------------------------------------------
    receive() external payable {
    }

    fallback() external {
    }
}
