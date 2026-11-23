// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InvoiceCheckout} from "../src/InvoiceCheckout.sol";
import {MockUSD8} from "../src/mocks/MockUSD8.sol";

/// @notice Deploys InvoiceCheckout. Same chain rules as Deploy.s.sol.
contract DeployInvoice is Script {
    address constant AEVUM_TUSD8 = 0x456569838f1d43009A91ebA4263147Afd7233483;
    uint256 constant ANVIL_CHAIN = 31337;

    function run() external returns (InvoiceCheckout checkout, address token) {
        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();
        address merchant = vm.envOr("MERCHANT", deployer);
        if (AEVUM_TUSD8.code.length > 0) {
            token = AEVUM_TUSD8;
        } else {
            require(block.chainid == ANVIL_CHAIN, "tUSD8 not found on this chain.");
            MockUSD8 mock = new MockUSD8();
            mock.mint(deployer, 1_000e6);
            token = address(mock);
        }
        checkout = new InvoiceCheckout(IERC20(token), merchant);
        vm.stopBroadcast();
        console.log("chainId  ", block.chainid);
        console.log("token    ", token);
        console.log("merchant ", merchant);
        console.log("InvoiceCheckout ", address(checkout));
    }
}
