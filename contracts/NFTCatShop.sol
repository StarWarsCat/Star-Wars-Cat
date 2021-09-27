// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import './XYZConfig.sol';

contract NFTCatShop is BaseUpgradeable, XYZConfig {
    using SafeMath for uint;
    mapping(address => mapping(uint => uint)) userItems;
    mapping(uint => uint) shopItems;
    mapping(uint => uint) exchangeItems;

    IERC20 public payToken;

    event BUY(address indexed _owner, uint _id, uint _val);
    event EXCHANGE(address indexed _owner, uint _id, uint _val);

//    constructor(address _payToken, bool _product) XYZConfig(_product) {
//        payToken = IERC20(_payToken);
//
//        shopItems[catFood] = 10_0000 * 1e18;
//        exchangeItems[catFood] = 9_0000 * 1e18;
//
//        auth[msg.sender] = true;
//    }

    function __NFTCatShop_init(address _payToken, bool _product) public initializer {
        XYZConfig.__XYZConfig_init(_product);

        payToken = IERC20(_payToken);

        shopItems[catFood] = 10_0000 * 1e18;
        exchangeItems[catFood] = 9_0000 * 1e18;

        auth[msg.sender] = true;
    }

    function setShopItem(uint _id, uint _coin) external onlyAdmin {
        shopItems[_id] = _coin;
    }

    function delShopItem(uint _id) external onlyAdmin {
        delete shopItems[_id];
    }

    function setExchangeItem(uint _id, uint _coin) external onlyAdmin {
        exchangeItems[_id] = _coin;
    }

    function delExchangeItem(uint _id) external onlyAdmin {
        delete exchangeItems[_id];
    }

    function addItem(address _owner, uint _id, uint _val) public onlyAuth {
        userItems[_owner][_id] = userItems[_owner][_id].add(_val);
    }

    function delItem(address _owner, uint _id, uint _val) public onlyAuth {
        userItems[_owner][_id] = userItems[_owner][_id].sub(_val);
    }

    function buy(uint _id, uint _num) external lock notPaused onlyExternal {
        require(shopItems[_id] > 0, "shopItems[_id] > 0");

        // 扣费
        payToken.transferFrom(msg.sender, address(this), shopItems[_id].mul(_num));

        // 给玩家增加道具
        userItems[msg.sender][_id] = userItems[msg.sender][_id].add(_num * 1e18);

        emit BUY(msg.sender, _id, _num);
    }

    function exchange(uint _id, uint _num) external lock notPaused onlyExternal {
        require(exchangeItems[_id] > 0, "exchangeItems[_id] > 0");

        // 给玩家扣道具
        userItems[msg.sender][_id] = userItems[msg.sender][_id].sub(_num * 1e18);

        // 扣费
        payToken.transfer(msg.sender, exchangeItems[_id].mul(_num));

        emit EXCHANGE(msg.sender, _id, _num);
    }

    function myItem(uint[] memory _ids) external view returns(uint[2][] memory) {
        require(_ids.length > 0, "_ids.length > 0");

        uint[2][] memory data = new uint[2][](_ids.length);
        for (uint i = 0; i < _ids.length; i++) {
            data[i] = [_ids[i], userItems[msg.sender][_ids[i]]];
        }

        return data;
    }

}
