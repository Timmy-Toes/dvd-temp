//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

library GChain {
  struct chain {
    uint256 startIndex;
    uint256 endIndex;
    mapping(uint256 => link) links;
  }

  //Positive balance is GUSD. Negative is BUSD.
  struct link {
    address depositor;
    int256 balance;
    uint256 prevIndex;
    uint256 nextIndex;
  }

  //Add a link to the end of the chain
  function pushLink(
    chain storage _chain,
    address _depositor,
    int256 _balance
  ) public {
    uint256 newEndIndex = _chain.endIndex + 1;
    //If the chain will be 2+ links long, we need to point to the previous link. Otherwise, point to zero.
    uint256 prevIndexValue = 0;
    if (newEndIndex > _chain.startIndex) {
      prevIndexValue = _chain.endIndex;
    }
    //Add a new link on the end of the chain
    _chain.links[newEndIndex] = link(_depositor, _balance, prevIndexValue, 0);
    //We only need to point if the chain is now at least 2 links long
    if (newEndIndex > _chain.startIndex) {
      _chain.links[_chain.endIndex].nextIndex = newEndIndex;
    }
    _chain.endIndex = newEndIndex;
  }

  //Remove a link from the front of the chain
  function unshiftLink(chain storage _chain) internal {
    if (_chain.startIndex < _chain.endIndex) {
      //We need the new start before we change anything
      uint256 newStartIndex = _chain.links[_chain.startIndex].nextIndex;
      //Do the actual modifications to our data
      delete (_chain.links[_chain.startIndex]);
      _chain.links[newStartIndex].prevIndex = 0;
      _chain.startIndex = newStartIndex;
    } else if (_chain.startIndex == _chain.endIndex) {
      lastPopLink(_chain);
    }
    //Don't unshift if there is nothing in the chain
  }

  //Remove a link from the end of the chain
  //This is only really used in yank() below
  function popLink(chain storage _chain) internal {
    if (_chain.startIndex < _chain.endIndex) {
      //We need the new end before we change anything
      uint256 newEndIndex = _chain.links[_chain.endIndex].prevIndex;
      //Do the actual modifications to our data
      delete (_chain.links[_chain.endIndex]);
      _chain.links[newEndIndex].nextIndex = 0;
      _chain.endIndex = newEndIndex;
    } else if (_chain.startIndex == _chain.endIndex) {
      lastPopLink(_chain);
    }
    //Don't pop if there is nothing in the chain
  }

  //Delete the final link from the chain
  function lastPopLink(chain storage _chain) private {
    delete (_chain.links[_chain.startIndex]);
    _chain.startIndex++;
  }

  //Remove a link from within the chain
  function yankLink(chain storage _chain, uint256 _index) internal {
    //If we are trying to yank the first item in the chain, just unshift it
    if (_index == _chain.startIndex) {
      unshiftLink(_chain);
      (_chain);
    } else if (_index == _chain.endIndex) {
      popLink(_chain);
    } else {
      //First, configure adjacent chain members to skip the yanked entry
      uint256 nextLinkIndex = _chain.links[_index].nextIndex;
      uint256 prevLinkIndex = _chain.links[_index].prevIndex;
      _chain.links[prevLinkIndex].nextIndex = nextLinkIndex;
      _chain.links[nextLinkIndex].prevIndex = prevLinkIndex;
      //Now delete our item
      delete (_chain.links[_index]);
    }
  }

  //Add up the total balance and return it
  function getTotalBalance(chain storage _chain)
    internal
    view
    returns (int256 _totalBalance)
  {
    _totalBalance = 0;
    uint256 chainIndex = _chain.startIndex;
    while (chainIndex <= _chain.endIndex && chainIndex != 0) {
      _totalBalance += _chain.links[chainIndex].balance;
      chainIndex = _chain.links[chainIndex].nextIndex;
    }
    return _totalBalance;
  }

  //Add up the total balance from several deposits and return it
  function getTotalOfLinks(chain storage _chain, uint256[] storage _linkIndexes)
    internal
    view
    returns (int256 _totalOfLinks)
  {
    _totalOfLinks = 0;
    for (uint256 i = 0; i < _linkIndexes.length; i++) {
      _totalOfLinks += _chain.links[_linkIndexes[i]].balance;
    }
    return _totalOfLinks;
  }

  //Return the depositors and amounts for all links
  function getLinks(chain storage _chain)
    internal
    view
    returns (address[] memory _depositors, int256[] memory _balances)
  {
    if (_chain.startIndex > _chain.endIndex) {
      return (_depositors, _balances);
    }
    uint256 chainIndex = _chain.startIndex;
    _depositors = new address[](1 + _chain.endIndex - _chain.startIndex);
    _balances = new int256[](1 + _chain.endIndex - _chain.startIndex);
    while (chainIndex <= _chain.endIndex && chainIndex != 0) {
      _depositors[chainIndex - _chain.startIndex] = _chain.links[chainIndex].depositor;
      _balances[chainIndex - _chain.startIndex] = _chain.links[chainIndex].balance;
      chainIndex = _chain.links[chainIndex].nextIndex;
    }
    return (_depositors, _balances);
  }
}
