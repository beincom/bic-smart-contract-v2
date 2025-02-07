// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

interface IBicForwarder {
    event AddedController(address indexed controller);
    event RemovedController(address indexed controller);
    event Requested(address indexed controller, address indexed from, address indexed to, bytes data, uint256 value);
    error NotController();
    error AlreadyController();
    struct RequestData {
        address from;
        address to;
        bytes data;
        uint256 value;
    }

    function forwardRequest(RequestData memory requestData) external;
}