// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InvoiceCheckout} from "../../src/InvoiceCheckout.sol";

interface ITUSD8F is IERC20 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/// @notice Invoice flow against the REAL tUSD8 on a local fork of Aevum testnet.
contract InvoiceForkTest is Test {
    ITUSD8F constant TUSD8 = ITUSD8F(0x456569838f1d43009A91ebA4263147Afd7233483);

    function test_realTusd8_invoicePayFlow() public {
        address merchant = makeAddr("merchant");
        address buyer = makeAddr("buyer");
        InvoiceCheckout checkout = new InvoiceCheckout(TUSD8, merchant);
        deal(address(TUSD8), buyer, 10e6);
        bytes32 orderId = keccak256("fork-invoice-1");

        vm.prank(merchant);
        checkout.createInvoice(orderId, 3e6);

        // Wrong amount is rejected before any funds move.
        vm.startPrank(buyer);
        TUSD8.approve(address(checkout), 10e6);
        vm.expectRevert(abi.encodeWithSelector(InvoiceCheckout.WrongAmount.selector, orderId, 3e6, 2e6));
        checkout.pay(orderId, 2e6);

        checkout.pay(orderId, 3e6);
        vm.stopPrank();

        assertEq(TUSD8.balanceOf(merchant), 3e6);
        assertEq(TUSD8.balanceOf(buyer), 7e6);
        assertTrue(checkout.isPaid(orderId));
        assertEq(checkout.paymentOf(orderId).amount, 3e6);
    }
}
