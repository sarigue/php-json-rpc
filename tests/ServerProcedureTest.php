<?php

namespace Rambler\JsonRpc\Tests;

use \Rambler\JsonRpc\Server;

class A
{
    public function getAll($p1, $p2, $p3 = 4)
    {
        return $p1 + $p2 + $p3;
    }
}

class B
{
    public function getAll($p1)
    {
        return $p1 + 2;
    }
}

class ServerProcedureTest extends \PHPUnit_Framework_TestCase
{
    /**
     * @expectedException \BadFunctionCallException
     */
    public function testProcedureNotFound()
    {
        $server = new Server;
        $server->executeProcedure('a');
    }

    /**
     * @expectedException \BadFunctionCallException
     */
    public function testCallbackNotFound()
    {
        $server = new Server;
        $server->register(
            'b',
            function () {
            }
        );
        $server->executeProcedure('a');
    }

    /**
     * @expectedException \BadFunctionCallException
     */
    public function testClassNotFound()
    {
        $server = new Server;
        $server->bind('getAllTasks', 'c', 'getAll');
        $server->executeProcedure('getAllTasks');
    }

    /**
     * @expectedException \BadFunctionCallException
     */
    public function testMethodNotFound()
    {
        $server = new Server;
        $server->bind('getAllTasks', 'A', 'getNothing');
        $server->executeProcedure('getAllTasks');
    }

    public function testIsPositionalArguments()
    {
        $server = new Server;
        $this->assertFalse(
            $server->isPositionalArguments(
                ['a' => 'b', 'c' => 'd'],
                ['a' => 'b', 'c' => 'd']
            )
        );

        $server = new Server;
        $this->assertTrue(
            $server->isPositionalArguments(
                ['a', 'b', 'c'],
                ['a' => 'b', 'c' => 'd']
            )
        );
    }

    public function testBindNamedArguments()
    {
        $server = new Server;
        $server->bind('getAllA', 'Rambler\JsonRpc\Tests\A', 'getAll');
        $server->bind('getAllB', 'Rambler\JsonRpc\Tests\B', 'getAll');
        $server->bind('getAllC', new B, 'getAll');
        $this->assertEquals(6, $server->executeProcedure('getAllA', ['p2' => 4, 'p1' => -2]));
        $this->assertEquals(10, $server->executeProcedure('getAllA', ['p2' => 4, 'p3' => 8, 'p1' => -2]));
        $this->assertEquals(6, $server->executeProcedure('getAllB', ['p1' => 4]));
        $this->assertEquals(5, $server->executeProcedure('getAllC', ['p1' => 3]));
    }

    public function testBindPositionalArguments()
    {
        $server = new Server;
        $server->bind('getAllA', 'Rambler\JsonRpc\Tests\A', 'getAll');
        $server->bind('getAllB', 'Rambler\JsonRpc\Tests\B', 'getAll');
        $this->assertEquals(6, $server->executeProcedure('getAllA', [4, -2]));
        $this->assertEquals(2, $server->executeProcedure('getAllA', [4, 0, -2]));
        $this->assertEquals(4, $server->executeProcedure('getAllB', [2]));
    }

    public function testRegisterNamedArguments()
    {
        $server = new Server;
        $server->register(
            'getAllA',
            function ($p1, $p2, $p3 = 4) {
                return $p1 + $p2 + $p3;
            }
        );

        $this->assertEquals(6, $server->executeProcedure('getAllA', ['p2' => 4, 'p1' => -2]));
        $this->assertEquals(10, $server->executeProcedure('getAllA', ['p2' => 4, 'p3' => 8, 'p1' => -2]));
    }

    public function testRegisterPositionalArguments()
    {
        $server = new Server;
        $server->register(
            'getAllA',
            function ($p1, $p2, $p3 = 4) {
                return $p1 + $p2 + $p3;
            }
        );

        $this->assertEquals(6, $server->executeProcedure('getAllA', [4, -2]));
        $this->assertEquals(2, $server->executeProcedure('getAllA', [4, 0, -2]));
    }

    /**
     * @expectedException \InvalidArgumentException
     */
    public function testTooManyArguments()
    {
        $server = new Server;
        $server->bind('getAllC', new B, 'getAll');
        $server->executeProcedure('getAllC', ['p1' => 3, 'p2' => 5]);
    }

    /**
     * @expectedException \InvalidArgumentException
     */
    public function testNotEnoughArguments()
    {
        $server = new Server;
        $server->bind('getAllC', new B, 'getAll');
        $server->executeProcedure('getAllC');
    }

    /**
     * @expectedException \Rambler\JsonRpc\Exceptions\ResponseEncodingFailure
     */
    public function testInvalidResponse()
    {
        $server = new Server;
        $server->getResponse([pack("H*", 'c32e')], ['id' => 1]);
    }
}
