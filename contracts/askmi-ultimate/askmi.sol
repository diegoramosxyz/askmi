//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./askmi-functions.sol";

// TODO:
// - Make the answers updatable
// - Maybe allow the responder to write an "AD" about his
// expertise, social media and others

// RESPONDER: The owner of the contract.
// QUESTIONER: Anyone who asks a question.
// EXCHANGE: The exchange between the questioner asking
// as question and the responder answering

// @title A question-and-answer smart contract
// @author Diego Ramos
contract AskMi {
    /* ---------- VARIABLES ---------- */
    // @notice The owner of this smart contract (askmi instance)
    address public owner;

    // @dev Variable used to prevent re-entrancy
    bool private locked;

    // @notice Prevents the ask() function from being called
    bool public disabled;

    // @notice The tip cost and token address for all exchanges
    Tip private tip;

    // @dev Address designated to receive all dev fees
    address private dev;

    // @notice The dev fee percentage (balance/200 = 0.5%)
    uint256 public fee = 200;

    // @notice An array of all unique addresses which have asked a question
    address[] private questioners;

    // @notice Mapping pointing to the possition of a questioner in the questioners array
    mapping(address => uint256) private questionersIndex;

    // @notice The list of questions from a questioner
    mapping(address => Exchange[]) private exchanges;

    // @notice List of token addresses (0x0 for ETH) accepted as payment by the responder
    address[] private supportedTokens;

    // @dev Mapping pointing to the possition of supported tokens in the supportedTokens array
    mapping(address => uint256) private supportedTokensIndex;

    // @dev The tiers for each supported token (0x0 for ETH)
    mapping(address => uint256[]) private tiers;

    /* ---------- STRUCTS ---------- */

    // The multihash representation of an IPFS' CID
    struct Cid {
        string digest;
        uint256 hashFunction;
        uint256 size;
    }

    struct Tip {
        address token;
        uint256 tip;
    }

    struct Exchange {
        Cid question;
        Cid answer;
        address tokenAddress;
        uint256 exchangeIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
        uint256 tips;
    }

    /* ---------- CONSTRUCTOR ---------- */

    // @param _dev The developer's address
    // @param _owner This contract's owner
    // @param _tiers The prices to ask a question
    // @param _tip The cost to tip an exchange
    // @param _token Address of the first supported token (0x0 for ETH)
    constructor(address _dev, address _owner) {
        dev = _dev;
        owner = _owner;

        // Occupy the first index of the questioners
        // array to allow for array lookups
        questioners.push(address(0));
    }

    // Make the smart contract payable
    // receive() external payable {}

    /* ---------- EVENTS ---------- */

    // event QuestionAnswered(address _questioner, uint256 _exchangeIndex);

    /* ---------- GETTER FUNCTIONS ---------- */

    // @notice Get the complete tiers array
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getTip() external view returns (uint256, address) {
        return (tip.tip, tip.token);
    }

    // @notice Get the complete tiers array
    function getTiers(address _tokenAddress)
        external
        view
        returns (uint256[] memory)
    {
        return tiers[_tokenAddress];
    }

    // @notice Get the complete questioners array.
    function getQuestioners() external view returns (address[] memory) {
        return questioners;
    }

    // @notice Get all of the questions asked by one questioner
    function getQuestions(address _questioner)
        external
        view
        returns (Exchange[] memory)
    {
        return exchanges[_questioner];
    }

    /* ---------- UPDATE FUNCTIONS ---------- */

    function toggleDisabled(address _functionsContract) external {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature("toggleDisabled()")
        );
        require(success, "toggleDisabled() failed");
    }

    // @notice Update the tip and tiers array
    function updateTiers(
        address _functionsContract,
        address _tokenAddress,
        uint256[] memory _newTiers
    ) external {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature(
                "updateTiers(address,uint256[])",
                _tokenAddress,
                _newTiers
            )
        );
        require(success, "updateTiers() failed");
    }

    function updateTip(
        address _functionsContract,
        uint256 _tip,
        address _token
    ) external {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature("updateTip(uint256,address)", _tip, _token)
        );
        require(success, "updateTip() failed");
    }

    /* ---------- PRIMARY FUNCTIONS ---------- */

    // @notice Ask a question to the RESPONDER
    // @param _tokenAddress Address of a supported token
    // @param _digest The digest output of hash function in hex with prepended '0x'
    // @param _hashFunction The hash function code for the function used
    // @param _size The length of digest
    // @param _tierIndex The index of the selected tier in the tiers array
    function ask(
        address _functionsContract,
        address _tokenAddress,
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _tierIndex
    ) external payable {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature(
                "ask(address,string,uint256,uint256,uint256)",
                _tokenAddress,
                _digest,
                _hashFunction,
                _size,
                _tierIndex
            )
        );
        require(success, "ask() failed");
    }

    // @notice The questioner or the responder can remove a question and
    // a refund is issued
    // TODO: Maybe have the responder receive a fraction of the refund if the
    // questioner removes the question
    function remove(
        address _functionsContract,
        address _questioner,
        uint256 _exchangeIndex
    ) external {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature(
                "remove(address,uint256)",
                _questioner,
                _exchangeIndex
            )
        );
        require(success, "remove() failed");
    }

    // @notice The owner answers a question
    // @param _questioner The address which asked the question
    // @param _digest The digest output of hash function in hex with prepended '0x'
    // @param _hashFunction The hash function code for the function used
    // @param _size The length of digest
    // @param _exchangeIndex The index of the selected exchange in the array of exchanges of
    // the questioner
    function respond(
        address _functionsContract,
        address _questioner,
        string memory _digest,
        uint256 _hashFunction,
        uint256 _size,
        uint256 _exchangeIndex
    ) external {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature(
                "respond(address,string,uint256,uint256,uint256)",
                _questioner,
                _digest,
                _hashFunction,
                _size,
                _exchangeIndex
            )
        );
        require(success, "respond() failed");

        // emit QuestionAnswered(_questioner, _exchangeIndex);
    }

    // @notice Tip an exchange to highlight helpful content
    function issueTip(
        address _functionsContract,
        address _questioner,
        uint256 _exchangeIndex
    ) external payable {
        (bool success, ) = _functionsContract.delegatecall(
            abi.encodeWithSignature(
                "issueTip(address,uint256)",
                _questioner,
                _exchangeIndex
            )
        );
        require(success, "issueTip() failed");
    }
}
