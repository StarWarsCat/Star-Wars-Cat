// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract XYZConfig is Initializable {
    // 怀孕费用
    uint[5][] public pregnancyFee;
    //兑换消耗的bnb
    uint[4] public exchange_coin;
    // 購買卡槽bnb費用
    uint[6] public buySlot_bnb;

    // 同等级猫各种系列的概率
    uint[] public cat_stype_rate;
    // 产出母猫概率
    uint public female_cat_rate;

    uint8 constant public MALE = 1; //公猫
    uint8 constant public FEMALE = 2; // 母猫

    uint constant STEP_BABY = 1; // 幼猫
    uint constant STEP_AUDLT = 2; //成年猫

    uint constant catFood = 1; // 猫粮ID

    uint[] public basePower; // 激活后算力

    // 集卡加成(数量)
    uint[2][5] public totalAddPowerPercent;
    mapping(uint => uint[2][]) public addPowerPercent;
    // 集齐一套加成
    mapping(uint8 => uint16) public addGradePowerPercent;

    uint public homeInterval;

    //    constructor(bool _production) {
    //        initConfig(_production);
    //    }

    function __XYZConfig_init(bool _production) public initializer {
        pregnancyFee = [[0.1 ether, 0.2 ether, 0.3 ether, 0.4 ether, 0.5 ether], [0.1 ether, 0.2 ether, 0.3 ether, 0.4 ether, 0.5 ether]];
        exchange_coin = [0.3 ether, 0.8 ether, 2 ether, 3 ether];
        buySlot_bnb = [0.01 ether, 0.024 ether, 0.8 ether, 0.2 ether, 1 ether, 1 ether];
        cat_stype_rate = [40, 30, 20, 10];
        female_cat_rate = 20;
        basePower = [0.1 * 1e9, 0.5 * 1e9, 2.5 * 1e9, 5 * 1e9, 250 * 1e9, 250 * 1e9, 2.5 * 1e9];
        totalAddPowerPercent = [[uint(50), 10], [uint(100), 50], [uint(300), 100], [uint(500), 200], [uint(1000), 400]];
        addPowerPercent[1] = [[uint(16), 63], [uint(80), 125], [uint(160), 250], [uint(320), 500]];
        addPowerPercent[2] = [[uint(8), 125], [uint(40), 250], [uint(80), 500], [uint(160), 1000]];
        addPowerPercent[3] = [[uint(2), 500], [uint(10), 1000], [uint(20), 2000], [uint(40), 4000]];
        addPowerPercent[4] = [[uint(1), 1000], [uint(5), 2000], [uint(10), 4000], [uint(20), 8000]];
        addPowerPercent[5] = [[uint(1), 0]];
        addPowerPercent[6] = [[uint(1), 0]];
        addPowerPercent[7] = [[uint(4), 125], [uint(20), 250], [uint(40), 500], [uint(80), 1000]];
        addGradePowerPercent[1] = 1500;
        addGradePowerPercent[2] = 1500;
        addGradePowerPercent[3] = 1500;
        addGradePowerPercent[4] = 1500;
        homeInterval = 1 hours;
        initConfig(_production);
    }

    function initConfig(bool _production) internal {
        if (!_production) {
            // 测试环境
            homeInterval = 5 minutes;

            buySlot_bnb = [0.0001 ether, 0.0005 ether, 0.001 ether, 0.025 ether, 0.3 ether, 0.3 ether];
            exchange_coin = [0.003 ether, 0.008 ether, 0.02 ether, 0.03 ether];
            pregnancyFee = [[0.001 ether, 0.002 ether, 0.003 ether, 0.004 ether, 0.005 ether], [0.001 ether, 0.002 ether, 0.003 ether, 0.004 ether, 0.005 ether]];
        }
    }
}
