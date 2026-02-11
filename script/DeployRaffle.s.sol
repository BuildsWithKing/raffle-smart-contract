// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Imports the Script contract from the forge-std library,Raffle, HelperConfig and CreateSubscription contracts.
import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interaction.s.sol";

contract DeployRaffle is HelperConfig {
    /// @notice The run function is the entry point for the script, which deploys the Raffle contract using the configuration from HelperConfig.
    function run() public {
        deployContract();
    }

    /** @notice This function deploys the Raffle contract using the configuration from HelperConfig. 
                It also creates and funds a VRF subscription if one does not already exist, and adds the Raffle contract as a consumer of the VRF subscription.
    */
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // Local => deploy mocks, get local config
        // sepolia => get sepolia config
        HelperConfig.NetworkConfig memory config  = helperConfig.getConfig();

        if(config.subscriptionId == 0) {
            // Create a new subscription if there is no subscriptionId
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator, config.account);

            // Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);

        }

        // Deploy the raffle contract
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add the raffle contract as a consumer of the VRF subscription
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (raffle, helperConfig);
    }
}