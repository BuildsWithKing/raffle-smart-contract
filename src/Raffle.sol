// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Imports the VRFConsumerBaseV2Plus contract and VRFV2PlusClient library from Chainlink
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title A sample Raffle contract
 *     @author Michealking (@BuildsWithKing)
 *     @notice This contract is for creating a sample raffle
 *     @dev Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    // ======================================= Errors =============================================
    /// @notice Thrown when a player tries to enter the raffle while a winner is being calculated.
    error Raffle__RaffleNotOpen();

    /// @notice Thrown when the ETH sent is less than the entrance fee.
    error Raffle__SendMoreToEnterRaffle();

    /// @notice Thrown when not enough time has passed to pick a winner.
    error Raffle__NotEnoughTimeHasPassed();

    /// @notice Thrown when the performUpkeep function is called but upkeep is not needed.
    /// @param balance The balance of the contract at the time of the call.
    /// @param playersLength The number of players in the raffle at the time of the call.
    /// @param raffleState The state of the raffle at the time of the call.
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /// @notice Thrown when the payment to the winner fails.
    error Raffle__PaymentFailed();

    // ======================================= Type Declarations ==================================
    /// @notice Enum representing the state of the raffle.
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    // ======================================= State Variables ====================================
    /// @notice Number of confirmations the Chainlink node should wait before responding.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice Number of random words to request.
    uint32 private constant NUM_WORDS = 1;

    /// @notice Records the raffle entrance fee.
    uint256 private immutable i_entranceFee;

    /// @notice Records the raffle interval between lottery rounds.
    /// @dev The duration of the lottery in seconds.
    uint256 private immutable i_interval;

    /// @notice Records the maximum gas price for the callback function in wei.
    bytes32 private immutable i_keyHash;

    /// @notice Records the subscription ID that this contract uses for funding requests.
    uint256 private immutable i_subscriptionId;

    /// @notice Records the limit for how much gas to use for the callback request in wei.
    uint32 private immutable i_callbackGasLimit;

    /// @notice Records the players in the raffle.
    /// @dev This is an array of payable addresses.
    address payable[] private s_players;

    /// @notice Records the last timestamp when a raffle round started.
    uint256 private s_lastTimestamp;

    /// @notice Records the recent winners of the raffle.
    address[] public s_recentWinners;

    /// @notice Records the state of the raffle.
    RaffleState private s_raffleState;

    // ===================================== Events ==============================================
    /// @notice Emitted when a player enters the raffle
    /// @param player The address of the player that entered the raffle
    event RaffleEntered(address indexed player);

    /// @notice Emitted when a random number is requested to pick a winner.
    /// @param requestId The ID of the VRF request.
    event RequestedRaffleWinner(uint256 indexed requestId);

    /// @notice Emitted when a winner is picked.
    /// @param winner The address of the winner.
    event WinnerPicked(address indexed winner);

    // ======================================= Constructor ========================================
    /// @notice Sets the raffle's entrance fee at deployment
    /// @param entranceFee The entrance fee for the raffle
    /// @param interval The time interval between raffle rounds
    /// @param vrfCoordinator The address of the Chainlink VRF Coordinator
    /// @param gasLane The key hash for the maximum gas price to pay for a VRF request
    /// @param subscriptionId The subscription ID for funding VRF requests
    /// @param callbackGasLimit The gas limit for the VRF callback function
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // ======================================= External Write Functions ===========================
    /// @notice Allows a player to enter the raffle by paying the entrance fee.
    function enterRaffle() external payable {
        // Check if the raffle is open for entries
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        // require(msg.value >= i_entranceFee, "Not enough ETH sent to enter the raffle");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        // Revert if the amount of ETH sent is less than the entrance fee
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        // Add the sender to the list of players
        s_players.push(payable(msg.sender));

        // Emit the event RaffleEntered.
        emit RaffleEntered(msg.sender);
    }

    /**
     * @notice This is the function that the Chainlink Automation nodes call to check if upkeep is needed.
     *     @dev This is the function that the chainlink nodes call to check if the conditions for picking a winner are met. The conditions are:
     *     1. Enough time has passed since the last raffle round (based on the interval).
     *     2. The raffle is currently open for entries.
     *     3. The contract has a balance (there are players who have entered the raffle).
     *     4. There is more than 1 player in the raffle (to ensure there is a winner to pick).
     *     @return upkeepNeeded This is a boolean that indicates whether upkeep is needed or not.
     *     @return performData This is the data that is passed to the performUpkeep function when upkeep is needed.
     *             It is not used in this implementation, but it can be used to pass additional data if needed.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        // Check to see if enough time has passed, if the raffle is open, if there are players in the raffle, and if the contract has a balance.
        upkeepNeeded = ((block.timestamp - s_lastTimestamp) >= i_interval) && (s_raffleState == RaffleState.OPEN)
            && (address(this).balance > 0) && (s_players.length > 1);
        return (upkeepNeeded, bytes(""));
    }

    /// @notice Picks a random winner from the raffle players.
    // 1. Get a random number
    // 2. Use the random number to pick a winner
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */ ) external {
        /*  Check if upkeep is needed by calling the checkUpkeep function. 
            This is redundant since the Chainlink Automation nodes will only call performUpkeep if checkUpkeep returns true, 
            but it is good practice to include this check to prevent someone from calling performUpkeep directly and causing unintended consequences.
        */
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // Set the raffle state to calculating to prevent new entries while picking a winner.
        s_raffleState = RaffleState.CALCULATING;

        // Create the request object for the VRF request.
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        // Request random number from chainlink VRF.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        // Emit the event RequestedRaffleWinner.
        emit RequestedRaffleWinner(requestId);
    }

    /// @notice Callback function used by VRF Coordinator to return the random words.
   // /// @param requestId The ID of the VRF request.
    /// @param randomWords The array of random words returned by the VRF Coordinator.
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        // Use the random number to pick a winner from the list of players.
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];

        // Push the recent winner to the list of recent winners.
        s_recentWinners.push(recentWinner);

        // Reset the state of the raffle for the next round.
        s_raffleState = RaffleState.OPEN;

        // Reset the list of players for the next round.
        s_players = new address payable[](0);

        // Update the last timestamp to the current time for the next round.
        s_lastTimestamp = block.timestamp;

        // Emit the event WinnerPicked.
        emit WinnerPicked(recentWinner);

        // Pay the winner by sending them all the ETH in the contract.
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__PaymentFailed();
        }
    }

    // ====================================== External Read Functions ==============================
    /// @notice Returns the raffle's entrance fee.
    /// @return fee The raffle's fee.
    function getEntranceFee() external view returns (uint256 fee) {
        return i_entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    /// @notice Returns the raffle's current state (OPEN or CALCULATING).
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    /// @notice Returns a player at a specific index.
    /// @param indexOfPlayer The index of the player to retrieve.
    /// @return The address of the player at the specified index.
    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    /// @notice Returns the last timestamp when a raffle round started.
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    /// @notice Returns the address of the most recent winner.
    function getRecentWinner() external view returns (address) {
        return s_recentWinners[s_recentWinners.length - 1];
    }
}
