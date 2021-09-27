// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract BaseUpgradeable is Initializable {
    bool public isPaused;
    bool private locked;
    address public admin;
    address public adminPending;
    // auth account
    mapping(address => bool) public auth;

    event SetAdmin(address newAdmin);
    event SetAdminPending(address newAdminPending);
    event SetAuth(address account, bool authState);
    event SetIsPaused(bool isPaused);

    function __Base_init() public initializer {
        admin = msg.sender;

        emit SetAdmin(admin);
    }

    modifier lock() {
        require(!locked, 'lock: !locked');
        locked = true;
        _;
        locked = false;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "onlyAdmin");
        _;
    }

    modifier onlyAuth() {
        require(auth[msg.sender], "onlyAuth");
        _;
    }

    modifier onlyExternal() {
        address account = msg.sender;
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        require(0 == size || auth[msg.sender], "onlyExternal");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "notPaused");
        _;
    }

    function setAdminPending(address _adminPending) external onlyAdmin {
        adminPending = _adminPending;

        emit SetAdminPending(_adminPending);
    }

    function acceptAdmin() external {
        require(msg.sender == adminPending && msg.sender != address(0), "admin != adminPending");
        admin = adminPending;
        adminPending = address(0);

        emit SetAdmin(admin);
    }

    function setAuth(address _account, bool _authState) external onlyAdmin {
        require(auth[_account] != _authState, "setAuth: auth[_account] != _authState");
        auth[_account] = _authState;

        emit SetAuth(_account, _authState);
    }

    function setIsPaused(bool _isPaused) external onlyAdmin {
        require(isPaused != _isPaused, "setIsPaused: isPaused != _isPaused");
        isPaused = _isPaused;

        emit SetIsPaused(_isPaused);
    }

}
