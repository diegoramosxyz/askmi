//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// RESPONDER: The owner of the contract.
// QUESTIONER: Anyone who asks a question.
contract Dqanda {
    address public owner;
    // The price in wei required to ask a question
    uint256 public price; // This will become a mapping of price tiers

    constructor(uint256 _price) {
        owner = msg.sender;
        price = _price;

        // Occupy the first index
        questioners.push(address(0));
    }

    // Make the contract payable
    receive() external payable {}

    event QuestionAsked(address _questioner, uint256 _qIndex);
    event QuestionAnswered(address _questioner, uint256 _qIndex);
    event QuestionRemoved(address _questioner, uint256 _qIndex);

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy.");
        locked = true;
        _;
        locked = false;
    }

    struct Question {
        string question;
        string answer;
        uint256 qIndex;
        // The balance in wei paid to the owner for a response
        // This will vary depending on the price tiers
        uint256 balance;
    }

    // Questioners can ask multiple questions
    mapping(address => Question[]) public questionsMapping;

    // Helper function to get all of the questions made by
    // a questioner
    function getQuestions(address _questioner)
        public
        view
        returns (Question[] memory)
    {
        return questionsMapping[_questioner];
    }

    // Indices from the questioners array
    mapping(address => uint256) questionersIndex;

    // An array of all questioners. Needed for the UI.
    address[] public questioners;

    // Save new questioners
    function addQuestioner(address _questioner) internal {
        // If the questioner does not exist
        if (_questioner != address(0) && questionersIndex[_questioner] == 0) {
            // Save the index on the questionersIndex mapping
            questionersIndex[_questioner] = questioners.length;
            // Append the questioner to the questioners array
            questioners.push(_questioner);
        }
    }

    // Helper function to get the complete questioners array.
    function getQuestioners() public view returns (address[] memory) {
        return questioners;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Must be owner.");
        _;
    }

    modifier notOwner() {
        require(msg.sender != owner, "Unauthorized: Must not be owner.");
        _;
    }

    // Ensure the questioner is paying the right price
    modifier coversCost() {
        require(msg.value == price, "Payment is not equal to the price.");
        _;
    }

    // Anyone, but the owner can ask a questions
    function ask(string memory _question) public payable notOwner coversCost {
        // Save new questioners
        addQuestioner(msg.sender);

        uint256 qIndex = questionsMapping[msg.sender].length;

        // Initialize the question object
        questionsMapping[msg.sender].push(
            Question({
                question: _question,
                answer: "",
                balance: msg.value,
                qIndex: qIndex
            })
        );

        emit QuestionAsked(msg.sender, qIndex);
    }

    // Todo: Add option to pay removal fee to the responder
    // Remove a question and widthdraw funds
    function removeQuestion(uint256 _qIndex) public noReentrant {
        // Get all the questions from a questioner
        Question[] storage questions = questionsMapping[msg.sender];

        // Stop execution if the questioner has no questions
        require(questions.length > 0, "No questions available to remove.");

        // Check that the question has not been answered
        require(
            keccak256(bytes(questions[_qIndex].answer)) == keccak256(bytes("")),
            "Question already answered."
        );

        // Create a payment variable
        uint256 payment = questions[_qIndex].balance;

        if (questions.length == 1) {
            // In this case, the questioner is removing their last question
            // 1- Remove his address from the questioners array
            // 2- Reset questionersIndex
            // 3- Remove the last question from the questions array

            // Move the last element into the place to delete
            questioners[questionersIndex[msg.sender]] = questioners[
                questioners.length - 1
            ];

            // Remove the last element/duplicate
            questioners.pop();

            // Set questionersIndex to the default value: 0
            delete questionersIndex[msg.sender];

            // If there is only one element,
            // just remove the last element
            questions.pop();
        } else {
            // Delete question and shrink array

            // Get the last element of the array
            Question memory questionLastIndex = questions[questions.length - 1];

            // Change its qIndex value to match new index
            questionLastIndex.qIndex = _qIndex;

            // Move the last element into the place to delete
            questions[_qIndex] = questionLastIndex;

            // Remove the last element/duplicate
            questions.pop();
        }

        // Pay the questioner
        (bool success, ) = msg.sender.call{value: payment}("");
        require(success, "Failed to send Ether");

        emit QuestionRemoved(msg.sender, _qIndex);
    }

    // Only the owner can respond and get paid.
    function respond(
        address _questioner,
        string memory _answer,
        uint256 _qIndex
    ) public noReentrant onlyOwner {
        // Get all the questions from a questioner
        Question[] storage questions = questionsMapping[_questioner];

        // If the length of the questions array is less than the index,
        // then the question does not exist.
        require(questions.length >= _qIndex, "The question does not exist.");

        // Create payment variable
        uint256 payment = questions[_qIndex].balance;

        // Update one question based on the index
        questions[_qIndex] = Question({
            question: questions[_qIndex].question,
            answer: _answer,
            balance: 0 wei, // Update balance
            qIndex: _qIndex
        });

        // Pay the owner of the contract (The Responder)
        (bool success, ) = owner.call{value: payment}("");
        require(success, "Failed to send Ether");

        emit QuestionAnswered(_questioner, _qIndex);
    }
}
