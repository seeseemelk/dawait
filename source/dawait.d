module dawait;

import std.parallelism;
import std.container;
import core.thread.fiber;
import core.sync.semaphore;

version(unittest) import fluent.asserts;

private SList!Fiber fibersQueued = SList!Fiber();
private size_t globalWaitingOnThreads = 0;
private __gshared Semaphore globalSync;

/**
Creates an async task.
An async task is a task that will be running in a separate fiber, independent
from the current fiber.

Params:
	task = The task to run.
*/
void async(void delegate() task)
{
	auto fiber = new Fiber(task);
	fibersQueued.insert(fiber);
}

@("async queues task")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	fibersQueued.empty.should.equal(true).because("there should be no queued tasks at first");
	async({});
	fibersQueued.empty.should.equal(false).because("there should be a single task");
}

@("async should not immediately execute its task")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;
	auto executeIt = {executed = true;};
	async(executeIt);
	executed.should.equal(false).because("async should not execute its operand");
}

/**
Runs the argument in a separate task, waiting for the result.
*/
T await(T)(lazy T task)
in (Fiber.getThis() !is null && globalSync !is null)
{
	globalWaitingOnThreads++;
	shared finished = false;

	auto semaphore = globalSync;
	T result;
	scopedTask(
	{
		scope(exit) finished = true;
		assert(semaphore !is null);
		result = task;
		semaphore.notify();
	}).executeInNewThread();

	while (!finished)
	{
		Fiber.yield();
	}
	globalWaitingOnThreads--;

	return result;
}

@("await can run a quick thread")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;
	startScheduler(
	{
		await(executed = true);
	});
	executed.should.equal(true).because("a quick thread should run");
}

@("await can run a slow thread")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;

	bool largeTask()
	{
		import core.thread : Thread;
		Thread.sleep(2.seconds);
		executed = true;
		return true;
	}

	startScheduler(
	{
		await(largeTask());
	});
	executed.should.equal(true).because("a slow thread should run");
}

@("await should return the value that was calculated")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;

	bool someTask()
	{
		return true;
	}

	startScheduler(
	{
		executed = await(someTask());
	});
	executed.should.equal(true).because("a slow thread should run");
}

/**
Starts the scheduler.
*/
void startScheduler(void delegate() firstTask)
{
	globalSync = new Semaphore;
	async({firstTask();});

	while (!fibersQueued.empty)
	{
		auto fibersRunning = fibersQueued;
		fibersQueued = SList!Fiber();
		foreach (Fiber fiber; fibersRunning)
		{
			fiber.call();
			if (fiber.state != Fiber.State.TERM)
				fibersQueued.insert(fiber);
		}

		if (globalWaitingOnThreads > 0)
		{
			globalSync.wait();
		}
	}
}

@("startScheduler should run initial task")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;
	startScheduler({executed = true;});
	executed.should.equal(true).because("startScheduler should execute the initial task");
}

@("startScheduler should also run tasks registered before itself")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;
	async({executed = true;});
	startScheduler({});
	executed.should.equal(true).because("startScheduler should execute the task executed before itself");
}

@("startScheduler should also run tasks registered by the initial task")
unittest
{
	scope(exit) fibersQueued = SList!Fiber();
	bool executed = false;
	startScheduler(
	{
		async({executed = true;});
	});
	executed.should.equal(true).because("startScheduler should execute the task created during the initial task");
}
