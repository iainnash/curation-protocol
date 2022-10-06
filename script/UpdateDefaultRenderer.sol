// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import { CuratorFactory } from "../src/CuratorFactory.sol";
import { Curator } from "../src/Curator.sol";
import { ERC1967Proxy } from "../src/lib/proxy/ERC1967Proxy.sol";
import { SVGMetadataRenderer } from "../src/renderer/SVGMetadataRenderer.sol";

import { console2 } from "forge-std/console2.sol";

contract UpdateDefaultRenderer is Script {
    address internal factoryProxy;

    function setUp() public {
        factoryProxy = vm.envAddress("FACTORY_PROXY");
    }

    function run() public {
        vm.startBroadcast();

        deployCore();

        vm.stopBroadcast();
    }

    function deployCore() internal {
        address renderer = address(new SVGMetadataRenderer());
        CuratorFactory(factoryProxy).setDefaultMetadataRenderer(renderer);
        console2.log("New metadata impl: ");
        console2.log(renderer);
    }
}
