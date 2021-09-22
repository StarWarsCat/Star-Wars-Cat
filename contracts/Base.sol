// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Base {
    //避免重入。有调用外部合约的时候，可以谨慎使用！
    bool private unlocked = true;
    address public admin;
    // auth account
    mapping(address => bool) public auth;

    event SetAdmin(address newAdmin);
    event SetAuth(address account, bool authState);

    constructor() {
        admin = msg.sender;

        emit SetAdmin(msg.sender);
    }

    modifier lock() {
        require(unlocked == true, 'lock: unlocked == true');
        unlocked = false;
        _;
        unlocked = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyAuth() {
        require(auth[msg.sender], "onlyAuth");
        _;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    function setAuth(address _account, bool _authState) external onlyAdmin {
        require(auth[_account] != _authState, "setAuth: auth[_account] != _authState");
        auth[_account] = _authState;

        emit SetAuth(_account, _authState);
    }

    modifier onlyExternal() {
        address account = msg.sender;
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        require(0 == size || auth[msg.sender], "onlyExternal");
        _;
    }
}
