// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    /// @notice This function creates a VRF subscription using the configuration from HelperConfig.
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    /// @notice This function creates a VRF subscription.
    /// @param vrfCoordinator The address of the VRF Coordinator contract.
    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("Creating subscription on Chain Id:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription Id is:", subId);
        console.log("Please update the subscription Id in your HelperConfig.s.sol file");
        return (subId, vrfCoordinator);
    }

    /// @notice The run function is the entry point for the script, which creates a VRF subscription using the configuration from HelperConfig.
    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    /// @notice Records the amount of Link token funded to the VRF subscription, which is set to 3 ether (equivalent to 3 LINK tokens).
    uint256 public constant FUND_AMOUNT = 3 ether; // = 3 LINK

    /// @notice This function funds a VRF subscription using the configuration from HelperConfig.
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    /// @notice This function funds a VRF subscription.
    /// @param vrfCoordinator The address of the VRF Coordinator contract.
    /// @param subscriptionId The subscription ID to fund.
    /// @param linkToken The address of the LINK token contract.
    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)
        public
    {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("On chain Id: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    /// @notice The run function is the entry point for the script, which funds a VRF subscription using the configuration from HelperConfig.
    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    /// @notice This function adds a consumer contract to the VRF subscription using the configuration from HelperConfig.
    ///` @param mostRecentlyDeployed The address of the most recently deployed consumer contract to add to the VRF subscription.
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    /// @notice This function adds a consumer contract to the VRF subscription.
    /// @param contractToAddToVrf The address of the consumer contract to add to the VRF subscription.
    /// @param vrfCoordinator The address of the VRF Coordinator contract.
    /// @param subId The subscription ID to which the consumer contract will be added.
    /// @param account The account performing the broadcast.
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To VRF Coordinator: ", vrfCoordinator);
        console.log("On chain Id: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    /// @notice The run function is the entry point for the script, which retrieves the most recently deployed Raffle contract and adds it as a consumer to the VRF subscription.
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
