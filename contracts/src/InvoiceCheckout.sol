// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IInvoiceEIP3009 {
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/// @title InvoiceCheckout (InvoiceRail)
/// @notice Invoice-gated stablecoin checkout. The merchant first registers an invoice
///         (orderId + exact amount). Only a registered invoice can be paid, and only for
///         exactly the registered amount. The `Paid` event is the receipt.
/// @dev Shanghai EVM compatible; no Cancun features. Payment logic mirrors Checkout.sol.
contract InvoiceCheckout {
    using SafeERC20 for IERC20;

    struct Payment {
        address payer;
        uint64 paidAt;
        uint256 amount;
    }

    struct Invoice {
        uint256 amount;
        bool exists;
    }

    IERC20 public immutable token;
    address public immutable merchant;

    mapping(bytes32 orderId => Payment) private _payments;
    mapping(bytes32 orderId => Invoice) private _invoices;

    event Paid(bytes32 indexed orderId, address indexed payer, uint256 amount);
    event InvoiceCreated(bytes32 indexed orderId, uint256 amount);

    error AlreadyPaid(bytes32 orderId);
    error ZeroAmount();
    error ZeroAddress();
    error OnlyMerchant();
    error InvoiceExists(bytes32 orderId);
    error UnknownInvoice(bytes32 orderId);
    error WrongAmount(bytes32 orderId, uint256 expected, uint256 actual);

    constructor(IERC20 token_, address merchant_) {
        if (address(token_) == address(0) || merchant_ == address(0)) revert ZeroAddress();
        token = token_;
        merchant = merchant_;
    }

    /// @notice Register an invoice. Only the merchant; amount must be > 0; no duplicates.
    function createInvoice(bytes32 orderId, uint256 amount) external {
        if (msg.sender != merchant) revert OnlyMerchant();
        if (amount == 0) revert ZeroAmount();
        if (_invoices[orderId].exists) revert InvoiceExists(orderId);
        _invoices[orderId] = Invoice({amount: amount, exists: true});
        emit InvoiceCreated(orderId, amount);
    }

    function invoiceOf(bytes32 orderId) external view returns (Invoice memory) {
        return _invoices[orderId];
    }

    function pay(bytes32 orderId, uint256 amount) external {
        _validate(orderId, amount);
        _record(orderId, msg.sender, amount);
        token.safeTransferFrom(msg.sender, merchant, amount);
    }

    function payWithAuthorization(
        bytes32 orderId,
        address from,
        uint256 amount,
        uint256 validAfter,
        uint256 validBefore,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _validate(orderId, amount);
        _record(orderId, from, amount);
        IInvoiceEIP3009(address(token)).receiveWithAuthorization(
            from, address(this), amount, validAfter, validBefore, authorizationNonce(orderId), v, r, s
        );
        token.safeTransfer(merchant, amount);
    }

    function authorizationNonce(bytes32 orderId) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), orderId));
    }

    function paymentOf(bytes32 orderId) external view returns (Payment memory) {
        return _payments[orderId];
    }

    function isPaid(bytes32 orderId) external view returns (bool) {
        return _payments[orderId].payer != address(0);
    }

    function _validate(bytes32 orderId, uint256 amount) private view {
        Invoice memory inv = _invoices[orderId];
        if (!inv.exists) revert UnknownInvoice(orderId);
        if (amount != inv.amount) revert WrongAmount(orderId, inv.amount, amount);
    }

    function _record(bytes32 orderId, address payer, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();
        if (_payments[orderId].payer != address(0)) revert AlreadyPaid(orderId);
        _payments[orderId] = Payment({payer: payer, paidAt: uint64(block.timestamp), amount: amount});
        emit Paid(orderId, payer, amount);
    }
}
