// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseUpgradeable.sol";
import "./INFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SharePool is BaseUpgradeable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    event WithdrawReward(address indexed user, uint amount0, uint amount1);

    uint[2] private _totalSupply;
    uint[2] private accShare; //累积单份收益
    mapping(address => uint[2]) private userShare;
    mapping(address => uint[2]) private _balances; // 未来猫 皇室猫
    mapping(address => uint[2]) private rewards;
    mapping(address => uint) private kingRewards;

    address public cpFeeAddr;
    IERC20 public payToken;
    IERC721 public catAddr;

    uint constant kingPercent = 20; //  猫王猫后20% 分红
    uint constant cat4Percent = 20; // 皇室猫20% 分红(如果没有 则给猫王猫后分)
    uint constant cat3Percent = 60; // 未来猫60% 分红

//    constructor(address _payToken, address _catAddr, address _cpFeeAddr) {
//        payToken = IERC20(_payToken);
//        catAddr = IERC721(_catAddr);
//        cpFeeAddr = _cpFeeAddr;
//    }
    function __SharePool_init(address _payToken, address _catAddr, address _cpFeeAddr) public initializer {
        BaseUpgradeable.__Base_init();
        payToken = IERC20(_payToken);
        catAddr = IERC721(_catAddr);
        cpFeeAddr = _cpFeeAddr;

        _totalSupply = [0, 0];
        accShare = [0, 0]; //累积单份收益
    }

    function setAToken(address _payToken) external onlyAdmin notPaused returns (bool) {
        payToken = IERC20(_payToken);
        return true;
    }

    function totalSupply() public view returns (uint[2] memory) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint[2] memory) {
        return _balances[account];
    }

    // 每天0点后台触发 把当天手续费转移过来 并分红
    function updateAccShare() external notPaused {
        require(msg.sender == cpFeeAddr, "msg.sender == cpFeeAddr");
        uint amount = payToken.balanceOf(msg.sender);
        payToken.transferFrom(msg.sender, address(this), amount);

        // 先分钱...
        amount = amount.mul(90).div(100); //cp轉賬需要手續費 扣除后剩下的分
        uint kingQueenAmount = amount.mul(kingPercent).div(100);
        uint cat3Amount = amount.mul(cat3Percent).div(100);
        uint cat4Amount = amount.mul(cat4Percent).div(100);

        //未来猫的分红基数
        accShare[0] = accShare[0].add(cat3Amount.div(_totalSupply[0]));

        if (_totalSupply[1] > 0) {
            // 皇室猫的分红基数
            accShare[1] = accShare[1].add(cat4Amount.div(_totalSupply[1]));
        } else {
            kingQueenAmount = kingQueenAmount.add(cat4Amount); // 没有皇室猫 那皇室猫的收益给猫王猫后了
        }

        // 给猫王猫后发收益
        uint queenAmount = kingQueenAmount.div(2);
        payToken.transfer(catAddr.ownerOf(2), queenAmount);
        payToken.transfer(catAddr.ownerOf(1), kingQueenAmount.sub(queenAmount));
    }

    function getUserShare(address _addr) internal view returns(uint, uint) {
        uint r0 = rewards[_addr][0].add(accShare[0].sub(userShare[_addr][0]).mul(_balances[_addr][0]));
        uint r1 = rewards[_addr][1].add(accShare[1].sub(userShare[_addr][1]).mul(_balances[_addr][1]));
        return (r0, r1);
    }

    function updateShare(address _addr) internal {
        // 需要更新玩家的收益
        if (userShare[_addr][0] != accShare[0]) {
            (rewards[_addr][0], rewards[_addr][1]) = getUserShare(_addr);
            userShare[_addr][0] = accShare[0];
            userShare[_addr][1] = accShare[1];
        }
    }

    function updateWeight(address _sender, uint[2] memory _totalSupply34, uint[2] memory _balances34) public onlyAuth {
        _totalSupply = _totalSupply34;
        _balances[_sender] = _balances34;
        updateShare(_sender);
    }

    function withdrawReward() public {
        updateShare(msg.sender);
        uint amount0 = rewards[msg.sender][0];
        uint amount1 = rewards[msg.sender][1];
        payToken.transfer(msg.sender, amount0);
        payToken.transfer(msg.sender, amount1);
        rewards[msg.sender] = [0, 0];
        emit WithdrawReward(msg.sender, amount0, amount1);
    }

    function getPoolInfo() public view returns (uint, uint, uint, uint, uint, uint, uint) {
        (uint r0, uint r1) = getUserShare(msg.sender);
        uint totalAmount = payToken.balanceOf(cpFeeAddr);
        uint weight0 = _balances[msg.sender][0];
        uint weight1 = _balances[msg.sender][1];
        uint total0 = _totalSupply[0];
        uint total1 = _totalSupply[1];
        return (totalAmount, weight0, weight1, rewards[msg.sender][0].add(r0), rewards[msg.sender][1].add(r1), total0, total1);
    }
}
