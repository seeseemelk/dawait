# dawait - A simple to use async/await library
This library provides a very easy-to-use async/await library for D.
It consists of only three functions: `async`, `await`, and `startScheduler`.
The library is build on top of D's fibers and allows for easier cooperative multitasking.

## Functionality
|Function|Description|
|--------|-----------|
|`startScheduler(void delegate() callback)`| Starts the scheduler with an initial task.|
|`async(void delegate() callback)`|Runs the given delegate in a separate fiber.|
|`await(lazy T task)`|Runs the expression in a separate thread. Once the thread has completely, the result is returned.|

## Code Example
```d
import std.stdio;

int calculateTheAnswer() {
	import core.thread : Thread;
	Thread.sleep(5.seconds);
	return 42;
}

void doTask() {
	writeln("Calculating the answer to life, the universe, and everything...");
	int answer = await(calculateTheAnswer());
	writeln("The answer is: ", answer);
}

void main() {
	startScheduler({
		doTask();
	});
}
```
