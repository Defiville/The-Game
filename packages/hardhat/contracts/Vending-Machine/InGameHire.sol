//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/math/SafeMath.sol";
import "./library/token/ERC20/SafeERC20.sol";

contract InGameHire {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Hire {
        address creator;
        address user;
        address token;
        uint256 amount;
        uint256 startDate;
        uint256 duration;
        uint256 redeemed;
        bool valid;
    }

    mapping (uint256 => Hire) public hires;
    uint256 nextHireId;

    event HireSomeone(
        address user, 
        address tokens, 
        uint256 amounts, 
        uint256 startDate, 
        uint256 duration
    );
    event IncreasePay(uint256 hireId, uint256 amount);
    event IncreasePeriod(uint256 hireId, uint256 period);
    event FireSomeone(uint256 hireId, uint256 payBack);

    function hireUser(
        address _user, 
        address _token, 
        uint256 _amount, 
        uint256 _startDate, 
        uint256 _duration
    ) external {
        _hireUser(_user, _token, _amount, _startDate, _duration);
    }

    function hireUserInBatch(
        address[] memory _users,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _startDates,
        uint256[] memory _durations

    ) external {
        for (uint256 i = 0; i < _users.length; i++) {
            _hireUser(
                _users[i],
                _tokens[i], 
                _amounts[i], 
                _startDates[i], 
                _durations[i]
            );
        }
    }

    function _hireUser(
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _startDate,
        uint256 _duration
        ) internal {
            require(_startDate >= block.timestamp);
            Hire memory hire = Hire(
                msg.sender, 
                _user, 
                _token, 
                _amount, 
                _startDate, 
                _duration,
                0,
                true
            );
            hires[nextHireId] = hire;
            nextHireId = nextHireId + 1;
            _receiveToken(_token, _amount);
            emit HireSomeone(_user, _token, _amount, _startDate, _duration);
    }

    function increaseHiringPay(uint256 _hireId, uint256 _amount) external {
        Hire storage hire = hires[_hireId];
        require(msg.sender == hire.creator, 'Only the creator');
        hire.amount = hire.amount.add(_amount);

        _receiveToken(hire.token, _amount);

        emit IncreasePay(_hireId, _amount);
    }

    function _receiveToken(address _token, uint256 _amount) internal {
        uint256 amountBefore = IERC20(_token).balanceOf(address(this)); 
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountAfter = IERC20(_token).balanceOf(address(this));
        require (amountAfter.sub(amountBefore) == _amount, 'Wrong amount received');
    }

    function _sendtoken(address _token, uint256 _amount, address recipient) internal {
        uint256 amountBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(recipient, _amount);
        uint256 amountAfter = IERC20(_token).balanceOf(address(this));
        require(amountBefore.sub(amountAfter) == _amount, 'Wrong amount sent');
    }

    function increaseHiringPeriod(uint256 _hireId, uint256 _duration) external {
        Hire storage hire = hires[_hireId];
        require (msg.sender == hire.creator, 'Only the creator');
        hire.duration = hire.duration.add(_duration);
        emit IncreasePeriod(_hireId, _duration);
    }

    function fireSomeone(uint256 _hireId) external {
        Hire storage hire = hires[_hireId];
        require(msg.sender == hire.creator, 'Only the creator');
        uint256 amountLeft = hire.amount.sub(hire.redeemed);
        _sendtoken(hire.token, amountLeft, msg.sender);
        hire.valid = false;
    }

    function redeemPay(uint256 _hireId, uint256 _amount) external {
        Hire storage hire = hires[_hireId];
        require(msg.sender == hire.user);
        require(redeemable(_hireId) >= _amount);
        _sendtoken(hire.token, _amount, hire.user);
    }

    function tokenPerSecond(uint256 _hireId) public view returns(uint256) {
        Hire memory hire = hires[_hireId];
        return hire.amount.div(hire.duration);
    }

    function redeemable(uint256 _hireId) public view returns(uint256) {
        Hire storage hire = hires[_hireId];
        require(hire.valid, 'Not valid');
        require(hire.startDate < block.timestamp, 'Not startet yet');
        require(hire.redeemed < hire.amount,'Reedemed all');
        uint256 timePassed = block.timestamp.sub(hire.startDate);
        uint256 maxRedeem = timePassed.mul(tokenPerSecond(_hireId));
        if (maxRedeem < hire.redeemed) {
            return 0;
        } else {
            return maxRedeem.sub(hire.redeemed);
        }
    }

}