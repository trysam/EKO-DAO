// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;


import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./StorageLib.sol";


contract Governor {

  IERC20 Ekotoken;


    // Modifier to ensure that user inputs an existing Proposal_ID
    modifier existingId(uint Proposal_ID){
      StorageLib.Tracker storage pt = StorageLib.getProposalTracker();
      if(!(Proposal_ID <= pt.Proposal_Tracker || Proposal_ID > 0)) 
            { revert ("Invalid");
            }else{
            _;
            }
    }


    // A modifier that is used to ensure that a user can not input an empty string
    modifier noEmptiness(string memory name){
      string memory a = "";
        if (
            keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked(a))
        ) {
            revert("Can't be empty");
        }else{
            _;
        }
    }
    

    // modifier to protect against address zero
    modifier addressValidation(address a) {
        if (a == address(0)){
          revert("Invalid address");
        }else{
          _;
        }
    }


    // modifier to ensure the voter has enough Eko Tokens to vote .
    modifier enoughEkoTokens(address a) {
      if (Ekotoken.balanceOf(a) < StorageLib.MINIMUM_TOKEN_REQUIREMENT){
        revert("Insufficient Balance");
      }else{
        _;
      }
    }


  //Ekotoken contract address is passed on governor contract initialization 
    constructor(address _token) addressValidation(_token) {
      Ekotoken = IERC20(_token);
    }


  // fucntion to create a new voting Proposal by Ekolance Admins.
  function newProposal(
    string calldata _name
  ) external noEmptiness(_name) {
    StorageLib.Tracker storage pt = StorageLib.getProposalTracker();
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    StorageLib.Proposal memory _newProposal = StorageLib.Proposal({
      name: _name,
      author: msg.sender,
      creationTime: block.timestamp, 
      votingDelay : StorageLib.VOTING_DELAY + block.timestamp,
      votingPeriod: StorageLib.VOTING_DELAY + StorageLib.VOTING_PERIOD + block.timestamp,
      votesFor: 0,
      votesAgainst: 0
    //   Bool state would need a chainlink integration.
    //   proposalState: false
    });
    pt.Proposal_Tracker += 1;
    uint Proposal_ID = pt.Proposal_Tracker;
    mp.proposal[Proposal_ID] = _newProposal;
    emit StorageLib.New_Proposal(msg.sender, _newProposal, Proposal_ID);
  }


  // function to view an existing proposal
  function viewProposal(
    uint Proposal_ID
  ) external view existingId(Proposal_ID) returns(StorageLib.Proposal memory){
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    return mp.proposal[Proposal_ID];
  }

  // function to get the number of existing proposals
  function getNumberOfProposals() external view returns(uint){
    StorageLib.Tracker storage pt = StorageLib.getProposalTracker();
    return pt.Proposal_Tracker;
  }

  // function to delegate voting power for a particular proposal
  function addVotingDelegate(
    uint Proposal_ID,
    address _delegate
  ) external existingId(Proposal_ID) addressValidation(_delegate){
      StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
      mp.votingDelegate[Proposal_ID][msg.sender] = _delegate;
      emit StorageLib.Add_Delegate(msg.sender, _delegate, Proposal_ID);
    }


  // function to view the delegate of an address on a particular proposal
  function viewDelegate(
    uint Proposal_ID,
    address _delegate
  ) external view existingId(Proposal_ID) addressValidation(_delegate)
  returns(address){
      StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
      return mp.votingDelegate[Proposal_ID][_delegate];
  }


  // function to remove voting delegate
  function removeDelegate(
    uint Proposal_ID
    ) external existingId(Proposal_ID){
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    address _delegate = mp.votingDelegate[Proposal_ID][msg.sender];
    delete mp.votingDelegate[Proposal_ID][msg.sender];
    emit StorageLib.Remove_Delegate(msg.sender, _delegate, Proposal_ID);
  }


  // function to vote on a proposal
  function voteFor(
    uint Proposal_ID
    )
    existingId(Proposal_ID) enoughEkoTokens(msg.sender) external{
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    if(
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.proposal[Proposal_ID].votingPeriod <= block.timestamp) ||
      (mp.proposalVoter[Proposal_ID][msg.sender].voted) 
      ) revert("Can't Vote");
    mp.proposalVoter[Proposal_ID][msg.sender].voted = true;
    mp.proposal[Proposal_ID].votesFor += 1;
    emit StorageLib.Vote_For(msg.sender, Proposal_ID);
  }

  // 3 >= 1
  // function to vote for a proposal as delegate.
  function voteForAsDelegate(
    uint Proposal_ID,
    address delegator
    ) 
    existingId(Proposal_ID) enoughEkoTokens(delegator) addressValidation(delegator) external{
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    if(
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.proposal[Proposal_ID].votingPeriod <= block.timestamp) ||
      (mp.proposalVoter[Proposal_ID][delegator].voted) ||
      (mp.votingDelegate[Proposal_ID][delegator] != msg.sender)
      ) revert("Can't Vote");
    mp.proposalVoter[Proposal_ID][delegator].voted = true;
    mp.proposal[Proposal_ID].votesFor += 1;
    emit StorageLib.Vote_For_As_Delegate(delegator, msg.sender, Proposal_ID);
  }


  // function to vote against a proposal
  function voteAgainst(
    uint Proposal_ID
    )
    existingId(Proposal_ID) enoughEkoTokens(msg.sender) external{
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    if(
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.proposal[Proposal_ID].votingPeriod <= block.timestamp) ||
      (mp.proposalVoter[Proposal_ID][msg.sender].voted) 
      ) revert("Can't Vote");
    mp.proposalVoter[Proposal_ID][msg.sender].voted = true;
    mp.proposal[Proposal_ID].votesAgainst += 1;
    emit StorageLib.Vote_Against(msg.sender, Proposal_ID);
  }


  // function to vote against on a proposal as delegate.
  function voteAgainstAsDelegate(
    uint Proposal_ID,
    address delegator
    ) 
    existingId(Proposal_ID) enoughEkoTokens(delegator) addressValidation(delegator) external{
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    if(
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.proposal[Proposal_ID].votingPeriod <= block.timestamp) ||
      (mp.proposalVoter[Proposal_ID][delegator].voted) ||
      (mp.votingDelegate[Proposal_ID][delegator] != msg.sender)
      ) revert("Can't Vote");
    mp.proposalVoter[Proposal_ID][delegator].voted = true;
    mp.proposal[Proposal_ID].votesAgainst += 1;
    emit StorageLib.Vote_Against_As_Delegate(delegator, msg.sender, Proposal_ID);
  }


  // function to delete the last proposal that has been created.
  function deleteProposal() external {
    // require function caller is an ekolance admin
    StorageLib.Tracker storage pt = StorageLib.getProposalTracker();
    StorageLib.Mappings storage mp = StorageLib.getMappingStruct();
    uint Proposal_ID = pt.Proposal_Tracker;
    if(
      (mp.proposal[Proposal_ID].votingDelay < block.timestamp) ||
      (Proposal_ID < 0)
    )revert("Can't delete");
    pt.Proposal_Tracker -= 1;
    delete mp.proposal[Proposal_ID];
    emit StorageLib.Delete_Proposal(msg.sender, Proposal_ID);
  }

}
