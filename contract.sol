// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct RentalRecord {
  // rental status
  bool exists;
  bool active;

  // rental terms
  address owner;
  uint256 price;
  uint256 maxRegistrationPeriods;

  // actual rent data
  address rentedBy;
  uint256 rentedAt;
  uint256 rentedFor;
  uint256 rentalExpiration;
}


contract Rental {
  uint public constant singleRegistrationPeriod = 90 seconds;

  // Stores all nft addresses that were listed
  address[] nfts;

  mapping (address => RentalRecord) rentalRecords;
  
  mapping (address => address[]) nftsByOwner;
  mapping (address => address[]) nftsRentedByAddress;
  
  constructor() {}


  function isOwner(address nftAddress) private view returns (bool) {
    return rentalRecords[nftAddress].owner == msg.sender;
  }

  function isRentee(address nftAddress) private view returns (bool) {
    return rentalRecords[nftAddress].rentedBy == msg.sender;
  }

  function isExists(address nftAddress) private view returns (bool) {
    return rentalRecords[nftAddress].exists == true;
  }

  function isActive(address nftAddress) private view returns (bool) {
    return rentalRecords[nftAddress].active == true;
  }

  function isAvailable(address nftAddress) private view returns (bool) {
    return 
      isExists(nftAddress) &&
      isActive(nftAddress) &&
      rentalRecords[nftAddress].rentalExpiration < block.timestamp;
  }
  

  modifier _owner(address nftAddress) {
    require(isOwner(nftAddress), "Sender not authorised");
    _;
  }

  modifier _rentee(address nftAddress) {
    require(isRentee(nftAddress), "Sender not authorised");
    _;
  }

  modifier _exists(address nftAddress) {
    require(isExists(nftAddress), "Rental does not exist");
    _;
  }

  modifier _doesNotExist(address nftAddress) {
    require(!isExists(nftAddress), "Rental already exists");
    _;
  }

  modifier _active(address nftAddress) {
    require(isActive(nftAddress), "Rental is not active");
    _;
  }

  modifier _available(address nftAddress) {
    require(isAvailable(nftAddress), "Rental is not available for rent");
    _;
  }


  /**
   * @dev Get info about the rental listing.
   * @param nftAddress The address of the nft.
   * @return RentalRecord
   */
  function getRentalRecord(address nftAddress) public view returns (RentalRecord memory) {
    return rentalRecords[nftAddress];
  }


  /**
   * @dev Get all nft addresses for created listings.
   * @return list of nft addresses.
   */
  function getAll() public view returns (address[] memory) {
    uint j = 0;
    address[] memory result = new address[](nfts.length);

    for (uint i = 0; i < nfts.length; i++) {
      if (isExists(nfts[i])) {
        result[j] = nfts[i];
        j++;
      }
    }

    return result;
  }

  /**
   * @dev Get all nft addresses for available listings.
   * @return list of nft addresses.
   */
  function getAllAvailable() public view returns (address[] memory) {
    uint j = 0;
    address[] memory result = new address[](nfts.length);

    for (uint i = 0; i < nfts.length; i++) {
      if (isAvailable(nfts[i])) {
        result[j] = nfts[i];
        j++;
      }
    }
    
    return result;
  }


  /**
   * @dev Get all nft addresses for created listings by owner.
   * @param addr The address of the renter.
   * @return list of nft addresses.
   */
  function getAllByOwner(address addr) public view returns (address[] memory) {
    uint j = 0;
    address[] memory result = new address[](nftsByOwner[addr].length);

    for (uint i = 0; i < nftsByOwner[addr].length; i++) {
      if (isExists(nftsByOwner[addr][i])) {
        result[j] = nftsByOwner[addr][i];
        j++;
      }
    }
    
    return result;
  }

  /**
   * @dev Get all nft addresses for available listings by owner.
   * @param addr The address of the renter.
   * @return list of nft addresses.
   */
  function getAllAvailableByOwner(address addr) public view returns (address[] memory) {
    uint j = 0;
    address[] memory result = new address[](nftsByOwner[addr].length);

    for (uint i = 0; i < nftsByOwner[addr].length; i++) {
      if (isAvailable(nftsByOwner[addr][i])) {
        result[j] = nftsByOwner[addr][i];
        j++;
      }
    }
    
    return result;
  }


  /**
   * @dev Get all nft addresses rented by addr.
   * @param addr The address of the rentee.
   * @return list of nft addresses.
   */
  function getAllRentedByAddress(address addr) public view returns (address[] memory) {
    uint j = 0;
    address[] memory result = new address[](nftsRentedByAddress[addr].length);

    for (uint i = 0; i < nftsRentedByAddress[addr].length; i++) {
      result[j] = nftsRentedByAddress[addr][i];
      j++;
    }
    
    return result;
  }

  /**
   * @dev Get all nft addresses rented by addr that are currently in rent.
   * @param nftAddress The address of the nft.
   * @return list of nft addresses.
   */
  function getCurrentRentee(address nftAddress) public view returns (address) {
    if (rentalRecords[nftAddress].rentalExpiration > block.timestamp) {
      return rentalRecords[nftAddress].rentedBy;
    }
    else {
      return address(0);
    }
  }

  

  /**
   * @dev Publish rental on the market.
   * @param nftAddress The address of the nft.
   * @param active boolean whether the rental is rentable once published.
   * @param price Price for oneRegistrationPeriod.
   * @param maxRegistrationPeriods Number of maximum singleRegistrationPeriods per rent.
   */
  function createRental(address nftAddress, bool active, uint256 price, uint256 maxRegistrationPeriods) public _doesNotExist(nftAddress) {    
    require(price > 0, "price must be greater than 0");
    require(maxRegistrationPeriods > 0, "maxRegistrationPeriods must be greater than 0");

    // TODO: check if nft belongs to msg.sender

    rentalRecords[nftAddress] = RentalRecord({
      exists: true,
      active: active,
      owner: msg.sender,
      price: price,
      maxRegistrationPeriods: maxRegistrationPeriods,
      rentedBy: address(0),
      rentedAt: 0,
      rentedFor: 0,
      rentalExpiration: 0
    });

    // Add to the list of all nfts
    bool wasListedBefore = false;
    for (uint i = 0; i < nfts.length; i++) {
      if (nfts[i] == nftAddress) {
        wasListedBefore = true;
        break;
      }
    }
    if (!wasListedBefore) {
      nfts.push(nftAddress);
    }

    // Add to the list of rentals by owner
    bool wasListedBefore2 = false;
    for (uint i = 0; i < nftsByOwner[msg.sender].length; i++) {
      if (nftsByOwner[msg.sender][i] == nftAddress) {
        wasListedBefore2 = true;
        break;
      }
    }
    if (!wasListedBefore2) {
      nftsByOwner[msg.sender].push(nftAddress);
    }

  }

  /**
   * @dev Set the active value for the listing.
   * @param nftAddress The address of the nft.
   */
  function removeRental(address nftAddress) public _exists(nftAddress) _owner(nftAddress) {
    require(rentalRecords[nftAddress].rentalExpiration < block.timestamp, "Rent in progress, cannot remove");
    rentalRecords[nftAddress].exists = false;
  }

  /**
   * @dev Set the active value for the listing.
   * @param nftAddress The address of the nft.
   * @param active New active value.
   */
  function setActive(address nftAddress, bool active) public _exists(nftAddress) _owner(nftAddress) {
    rentalRecords[nftAddress].active = active;
  }
  

  
  /**
   * @dev Rent nft for the given number of singleRegistrationPeriods.
   * @param nftAddress The address of the nft.
   * @param numRegistrationPeriods The number of registration periods to rent for.
   */
  function rent(address nftAddress, uint256 numRegistrationPeriods) public payable _available(nftAddress) {
    require(numRegistrationPeriods > 0, "numRegistrationPeriods must be greater than 0");
    require(numRegistrationPeriods <= rentalRecords[nftAddress].maxRegistrationPeriods, "You can not rent this nft for that long");
    require(rentalRecords[nftAddress].price * numRegistrationPeriods <= msg.value, "Price is too low");

    payable(rentalRecords[nftAddress].owner).transfer(msg.value);

    rentalRecords[nftAddress].rentedBy = msg.sender;
    rentalRecords[nftAddress].rentedAt = block.timestamp;
    rentalRecords[nftAddress].rentedFor = numRegistrationPeriods;
    rentalRecords[nftAddress].rentalExpiration = block.timestamp + singleRegistrationPeriod * numRegistrationPeriods;

    // Add to the list of rented nfts by address
    bool wasRentedBefore = false;
    for (uint i = 0; i < nftsRentedByAddress[msg.sender].length; i++) {
      if (nftsRentedByAddress[msg.sender][i] == nftAddress) {
        wasRentedBefore = true;
        break;
      }
    }
    if (!wasRentedBefore) {
      nftsRentedByAddress[msg.sender].push(nftAddress);
    }
  }

  /**
   * @dev Extend the rent of nft for the given number of singleRegistrationPeriods.
   * @param nftAddress The address of the nft.
   * @param numRegistrationPeriods The number of registration periods to rent for.
   */
  function extendRent(address nftAddress, uint numRegistrationPeriods) public payable _exists(nftAddress) _rentee(nftAddress) {
    require(numRegistrationPeriods > 0, "numRegistrationPeriods must be greater than 0");
    require(rentalRecords[nftAddress].price * numRegistrationPeriods <= msg.value, "Price is too low");

    payable(rentalRecords[nftAddress].owner).transfer(msg.value);

    rentalRecords[nftAddress].rentedFor += numRegistrationPeriods;
    rentalRecords[nftAddress].rentalExpiration += singleRegistrationPeriod * numRegistrationPeriods;
  }
}
