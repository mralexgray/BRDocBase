#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

#import "TestCase.h"

static const char* TestMethodSignature = "v16@0:8";

typedef struct {
	NSUInteger testsRun;
	NSUInteger testsPassed;
} BRTestResults;

extern void BRRunTests(Class testClass, BRTestResults* testResults);
extern BOOL BRRunTest(BRTestCase* testCase, SEL testMethod);

int main(int argc, char *argv[])
{
	BRTestResults testResults;
	int classCount = objc_getClassList(NULL, 0);
	if (classCount > 0) {
		Class* classes = malloc(classCount * sizeof(Class));
		objc_getClassList(classes, classCount);
		for (int i = 0; i < classCount; ++i) {
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			Class superClass = class_getSuperclass(classes[i]);
			while (superClass != nil) {
				if (superClass == [BRTestCase class]) {
					if (![classes[i] isAbstract]) {
						BRRunTests(classes[i], &testResults);
					}
					superClass = nil;
				} else {
					superClass = class_getSuperclass(superClass);
				}
			}
			[pool drain];
		}
		free(classes);
	}
	NSLog(@"Tests Completed.  %d run, %d passed", testResults.testsRun, testResults.testsPassed);
	return 0;
}


void BRRunTests(Class testClass, BRTestResults* testResults)
{
//	NSLog(@"running tests for %s", class_getName(testClass));
	BRTestCase* testCase = [[testClass alloc] init];
	Class currentClass = testClass;
	while (currentClass != nil) {
		unsigned int methodCount;
		Method* methods = class_copyMethodList(currentClass, &methodCount);
		for (int i = 0; i < methodCount; ++i) {
			SEL methodSelector = method_getName(methods[i]);
			const char* methodName = sel_getName(methodSelector);
			if ((strstr(methodName, "test") == methodName) && 
				(strcmp(method_getTypeEncoding(methods[i]), TestMethodSignature) == 0)) {
				testResults->testsPassed += BRRunTest(testCase, methodSelector) ? 1 : 0;
				testResults->testsRun += 1;
			}
		}
		free(methods);
		currentClass = class_getSuperclass(currentClass);
	}
	[testCase release];
}


BOOL BRRunTest(BRTestCase* testCase, SEL test)
{
	BOOL passed = NO;
//	NSLog(@"running test: %@, %s", [testCase class], sel_getName(test));
	@try {						
		[testCase setup];
		@try {
			[testCase performSelector:test];
			passed = YES;
		}
		@catch (BRTestFailureException* e) {
			NSLog(@"Test failure: %@, %s: %@\n\tfile: %@, line: %@",
				  [testCase class], sel_getName(test), [e reason], [e file], [e line]);
		}
		@finally {
			[testCase tearDown];
		}
	}
	@catch (NSException* e) {
		NSLog(@"Test error: %@, %s: %@", [testCase class], sel_getName(test), [e reason]);
	}
	return passed;
}
