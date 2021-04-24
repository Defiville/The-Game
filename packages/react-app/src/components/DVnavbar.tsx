import React from 'react';
import logo from './../img/SVG/logo.svg';
import { Navbar, Nav, Button } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';

<style type="text/css">
    {`
    .btn-flat {
      background-color: purple;
      color: white;
    }
    `}
  </style>

function DVnavbar() {
  return (

<Navbar className="navbar navbar-expand-lg navbar-light fixed-top">
<Navbar.Brand href="#">
  <img src={logo} height="50" alt="defiville logo" loading="lazy" />
</Navbar.Brand>
  <Navbar.Toggle aria-controls="basic-navbar-nav" />
  <Navbar.Collapse id="basic-navbar-nav">
    <Nav className="mr-auto" />
    <Nav>
      <Button variant="flat">Primary</Button>
      <Nav.Link href="#deets">More deets</Nav.Link>
      <Nav.Link eventKey={2} href="#memes">
        Dank memes
      </Nav.Link>
    </Nav>

  </Navbar.Collapse>
</Navbar>
);
}

export default DVnavbar;
