// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {EvictionVault} from "../src/Vault.sol";

contract EvictionVaultScript is Script {
    EvictionVault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address[] memory owners = new address[](2);
        owners[0] = vm.addr(vm.envUint("OWNER_ONE_PRIVATE_KEY"));
        owners[1] = vm.addr(vm.envUint("OWNER_TWO_PRIVATE_KEY"));

        vault = new EvictionVault(owners, 2);

        vm.stopBroadcast();
    }
}
