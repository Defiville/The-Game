import React from 'react';
import './Board.css';
import MapOverlay from './MapOverlay';


function Board() {
  return(
    <div className="board">
      <MapOverlay />
    </div>
  )
}

export default Board;
