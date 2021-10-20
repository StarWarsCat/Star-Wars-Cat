// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./BaseUpgradeable.sol";


contract AdminBaseUpgradeable is BaseUpgradeable {
    using SafeERC20 for IERC20;


    ///////////////////////////////// admin function /////////////////////////////////
    event AdminWithdrawNFT(address operator, address indexed tokenAddress, address indexed to, uint indexed tokenId);
    event AdminWithdrawToken(address operator, address indexed tokenAddress, address indexed to, uint amount);
    event AdminWithdraw(address operator, address indexed to, uint amount);

    /**
     * @dev adminWithdrawNFT
     */
    function adminWithdrawNFT(address _token, address _to, uint _tokenId) external onlyAdmin returns (bool) {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);

        emit AdminWithdrawNFT(msg.sender, _token, _to, _tokenId);
        return true;
    }

    /**
     * @dev adminWithdrawToken
     */
    function adminWithdrawToken(address _token, address _to, uint _amount) external onlyAdmin returns (bool) {
        IERC20(_token).safeTransfer(_to, _amount);

        emit AdminWithdrawToken(msg.sender, _token, _to, _amount);
        return true;
    }

    /**
     * @dev adminWithdraw
     */
    function adminWithdraw(address payable _to, uint _amount) external onlyAdmin returns (bool) {
        _to.transfer(_amount);

        emit AdminWithdraw(msg.sender, _to, _amount);
        return true;
    }

}
