// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InvoiceCheckout} from "../src/InvoiceCheckout.sol";
import {MockUSD8} from "../src/mocks/MockUSD8.sol";
import {Signing} from "./Signing.sol";

contract InvoiceCheckoutTest is Test {
    MockUSD8 token;
    InvoiceCheckout checkout;
    address merchant = makeAddr("merchant");
    address buyer;
    uint256 buyerKey;
    address relayer = makeAddr("relayer");
    bytes32 constant ORDER = keccak256("invoice-1");
    uint256 constant PRICE = 5e6;

    function setUp() public {
        (buyer, buyerKey) = makeAddrAndKey("buyer");
        token = new MockUSD8();
        checkout = new InvoiceCheckout(IERC20(address(token)), merchant);
        token.mint(buyer, 100e6);
        vm.prank(merchant);
        checkout.createInvoice(ORDER, PRICE);
    }

    function test_createInvoice_registers() public {
        bytes32 id = keccak256("invoice-2");
        vm.prank(merchant);
        vm.expectEmit(true, false, false, true, address(checkout));
        emit InvoiceCheckout.InvoiceCreated(id, 7e6);
        checkout.createInvoice(id, 7e6);
        InvoiceCheckout.Invoice memory inv = checkout.invoiceOf(id);
        assertTrue(inv.exists);
        assertEq(inv.amount, 7e6);
    }

    function test_createInvoice_revertsNonMerchant() public {
        vm.prank(buyer);
        vm.expectRevert(InvoiceCheckout.OnlyMerchant.selector);
        checkout.createInvoice(keccak256("x"), PRICE);
    }

    function test_createInvoice_revertsDuplicate() public {
        vm.prank(merchant);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.InvoiceExists.selector, ORDER));
        checkout.createInvoice(ORDER, PRICE);
    }

    function test_createInvoice_revertsZeroAmount() public {
        vm.prank(merchant);
        vm.expectRevert(InvoiceCheckout.ZeroAmount.selector);
        checkout.createInvoice(keccak256("z"), 0);
    }

    function test_pay_exactAmountSucceeds() public {
        vm.startPrank(buyer);
        token.approve(address(checkout), PRICE);
        vm.expectEmit(true, true, false, true, address(checkout));
        emit InvoiceCheckout.Paid(ORDER, buyer, PRICE);
        checkout.pay(ORDER, PRICE);
        vm.stopPrank();
        assertEq(token.balanceOf(merchant), PRICE);
        assertTrue(checkout.isPaid(ORDER));
        assertEq(checkout.paymentOf(ORDER).amount, PRICE);
    }

    function test_pay_revertsWrongAmount() public {
        vm.startPrank(buyer);
        token.approve(address(checkout), PRICE);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.WrongAmount.selector, ORDER, PRICE, PRICE - 1));
        checkout.pay(ORDER, PRICE - 1);
        vm.stopPrank();
        assertFalse(checkout.isPaid(ORDER));
    }

    function test_pay_revertsUnknownInvoice() public {
        bytes32 unknown = keccak256("nope");
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.UnknownInvoice.selector, unknown));
        checkout.pay(unknown, PRICE);
    }

    function test_pay_revertsSecondPayment() public {
        vm.startPrank(buyer);
        token.approve(address(checkout), 2 * PRICE);
        checkout.pay(ORDER, PRICE);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.AlreadyPaid.selector, ORDER));
        checkout.pay(ORDER, PRICE);
        vm.stopPrank();
    }

    function _sign(bytes32 orderId, uint256 value, uint256 validBefore)
        internal view returns (uint8 v, bytes32 r, bytes32 s)
    {
        Signing.Auth memory a = Signing.Auth({
            from: buyer, to: address(checkout), value: value, validAfter: 0,
            validBefore: validBefore, nonce: checkout.authorizationNonce(orderId)
        });
        return Signing.signReceive(vm, buyerKey, token.DOMAIN_SEPARATOR(), a);
    }

    function test_gasless_exactAmountSucceeds() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _sign(ORDER, PRICE, deadline);
        vm.prank(relayer);
        checkout.payWithAuthorization(ORDER, buyer, PRICE, 0, deadline, v, r, s);
        assertEq(token.balanceOf(merchant), PRICE);
    }

    function test_gasless_revertsWrongAmount() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _sign(ORDER, PRICE + 1, deadline);
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.WrongAmount.selector, ORDER, PRICE, PRICE + 1));
        checkout.payWithAuthorization(ORDER, buyer, PRICE + 1, 0, deadline, v, r, s);
    }

    function test_gasless_revertsUnknownInvoice() public {
        bytes32 unknown = keccak256("ghost");
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _sign(unknown, PRICE, deadline);
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.UnknownInvoice.selector, unknown));
        checkout.payWithAuthorization(unknown, buyer, PRICE, 0, deadline, v, r, s);
    }
}
