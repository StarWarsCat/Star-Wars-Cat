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
import "hardhat/console.sol";

interface IPool {
    function stake(address _sender, uint[] memory _tokenIds, uint _weight) external;
    function withdraw(address _sender, uint[] memory _tokenIds, uint _weight) external;
    function cat2slot(uint _catId) external returns(uint);
    function myStakeList(address _owner) external view returns (ICat.TokenInfo[] memory _cats);
    function getUserActive(address _sender) external view returns(uint[6][10] memory);
    function setUserActive(address _sender, uint[6][10] memory _data) external;
}

contract NFTCatActive is BaseUpgradeable, XYZConfig {
    ISlot public slotAddr;
    using SafeMath for uint;
    using Math for uint;
    IERC20 public payToken;
    ICat public catAddr;
    IPool public poolAddr;
    using EnumerableSet for EnumerableSet.AddressSet;
    address public feeTo;

    uint constant unactiveFee = 10_0000 * 1e18;

    event Unactive(address _sender, uint[] _catslotIds);
    event Active(address _sender, uint[] _catslotIds);

//    constructor(address _catAddr, address _slotAddr, address _payToken, address _poolAddr, address _feeTo, bool _product) XYZConfig(_product) {
//        catAddr = ICat(_catAddr);
//        slotAddr = ISlot(_slotAddr);
//        payToken = IERC20(_payToken);
//        poolAddr = IPool(_poolAddr);
//        feeTo = _feeTo;
//    }
    function initialize(address _catAddr, address _slotAddr, address _payToken, address _poolAddr, address _feeTo, bool _product) public initializer {
        BaseUpgradeable.__Base_init();
        XYZConfig.__XYZConfig_init(_product);
        catAddr = ICat(_catAddr);
        slotAddr = ISlot(_slotAddr);
        payToken = IERC20(_payToken);
        poolAddr = IPool(_poolAddr);
        feeTo = _feeTo;
    }

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

    // 增加算力
    function addActiveData(uint[6][10] memory _data, uint _grade, uint _stype, uint _power) internal pure returns(uint[6][10] memory) {
        _data[_grade][_stype] = _data[_grade][_stype].add(1);
        _data[_grade][4] = _data[_grade][4].add(1);
        _data[_grade][5] = _data[_grade][5].add(_power);
        _data[0][_stype] = _data[0][_stype].add(1);
        _data[0][4] = _data[0][4].add(1);

        return _data;
    }

    // 减少算力
    function reduceActiveData(uint[6][10] memory _data, uint _grade, uint _stype, uint _power) internal pure returns(uint[6][10] memory) {
        _data[_grade][_stype] = _data[_grade][_stype].sub(1);
        _data[_grade][4] = _data[_grade][4].sub(1);
        if (_data[_grade][5] < _power) {
            _data[_grade][5] = 0;
        } else {
            _data[_grade][5] = _data[_grade][5].sub(_power);
        }
        _data[0][_stype] = _data[0][_stype].sub(1);
        _data[0][4] = _data[0][4].sub(1);

        return _data;
    }

    // 激活卡槽
    function active(uint[] memory _catslotIds) external lock notPaused onlyExternal returns (bool) {
        require(_catslotIds.length >= 2, "_catslotIds.length >= 2");
        uint[6][10] memory activeData = poolAddr.getUserActive(msg.sender);
        for (uint i = 0; i < _catslotIds.length / 2; i++) {
            ICat.TokenInfo memory catInfo = catAddr.getTokenInfo(_catslotIds[i*2]);
            ISlot.TokenInfo memory slotInfo = slotAddr.getTokenInfo(_catslotIds[i*2 + 1]);

            require(catInfo.tokenId > 0, "catInfo.tokenId > 0");
            require(slotInfo.tokenId > 0, "slotInfo.tokenId > 0");

            // 判断是不是同一个类型的
            require(catInfo.grade == slotInfo.grade, "catInfo.grade == slotInfo.grade");
            require(catInfo.stype == slotInfo.stype, "catInfo.stype == slotInfo.stype");

            activeData = addActiveData(activeData, catInfo.grade, catInfo.stype, catInfo.power);   // 增加算力
        }
        uint power = calcPower(activeData);  // 计算总算力

        poolAddr.stake(msg.sender, _catslotIds, power.sub(activeData[0][5]));
        activeData[0][5] = power;
        poolAddr.setUserActive(msg.sender, activeData);


        emit Active(msg.sender, _catslotIds);

        return true;
    }

    // 取消激活卡槽
    function unactive(uint[] memory _catIds) external lock notPaused onlyExternal returns (bool) {
        require(_catIds.length > 0, "_catIds.length > 0");
        uint[] memory _catslotIds = new uint[](_catIds.length * 2);
        uint[6][10] memory activeData = poolAddr.getUserActive(msg.sender);
        for (uint i = 0; i < _catIds.length; i++) {
            ICat.TokenInfo memory catInfo = catAddr.getTokenInfo(_catIds[i]);
            uint _slotId = poolAddr.cat2slot(_catIds[i]);
            ISlot.TokenInfo memory slotInfo = slotAddr.getTokenInfo(_slotId);

            require(catInfo.tokenId > 0, "catInfo.tokenId > 0");
            require(slotInfo.tokenId > 0, "slotInfo.tokenId > 0");

            // 判断是不是同一个类型的
            require(catInfo.grade == slotInfo.grade, "catInfo.grade == slotInfo.grade");
            require(catInfo.stype == slotInfo.stype, "catInfo.stype == slotInfo.stype");

            _catslotIds[2 * i] = _catIds[i];
            _catslotIds[2 * i + 1] = _slotId;

            activeData = reduceActiveData(activeData, catInfo.grade, catInfo.stype, catInfo.power);
        }

        // 扣除费用
//        IERC20(payToken).transferFrom(msg.sender, feeTo, unactiveFee.mul(_catIds.length));

        uint power = calcPower(activeData);

        poolAddr.withdraw(msg.sender, _catslotIds, activeData[0][5].sub(power));
        activeData[0][5] = power;
        poolAddr.setUserActive(msg.sender, activeData);

        emit Unactive(msg.sender, _catslotIds);

        return true;
    }

    // 玩家激活貓列表
    function list() external view returns(ICat.TokenInfo[] memory) {
        return poolAddr.myStakeList(msg.sender);
    }
}
