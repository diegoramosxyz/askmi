//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

library ArrayAddOns {
    // Remove one element and shrink array
    function removeAndShrink(uint256[] storage arr, uint256 index) internal {
        require(arr.length > 0, "Can't remove from empty array");
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }
}
