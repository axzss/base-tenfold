// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  Minimal
/// @notice One `uint256` in a single storage slot, with one `external` setter.
///         No constructor, fallback, or events. `external` (not `public`)
///         skips the calldata-to-memory copy on the input.
contract Minimal {
    // Slot 0. Nothing else shares it.
    uint256 public x;

    /// @notice Overwrite the stored value.
    /// @dev    One SSTORE (~5k warm, ~22k cold) plus a calldata read.
    /// @param  _x New value to store.
    function set(uint256 _x) external {
        x = _x;
    }
}
