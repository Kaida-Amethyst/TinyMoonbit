#!/opt/homebrew/bin/python3

import subprocess
import os

test_files = ["fib.mbt", "gcd.mbt", "sum.mbt", "spill.mbt", "caltz.mbt", "binary.mbt", "ack.mbt"]

def run_command(command):
    """Runs a command and returns its output and error."""
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.stdout, result.stderr

def main():
    """Main function to run the test script."""

    # Step 1: Run moon check
    print("Running 'moon check'...")
    stdout, stderr = run_command("moon check")
    if "error:" in stderr.lower() or "error[" in stderr.lower():
        print("Project Cannot Pass Static Analysis")
        print(stderr)
        return

    # Step 2: Run moon test
    print("Running 'moon test'...")
    stdout, stderr = run_command("moon test")
    if "failed: 0" not in stdout:
        print("Project Internal Test Not Passed")
        print(stdout)
        print(stderr)
        return

    # Step 3: List of test files
    # print(f"Running tests for: {', '.join(test_files)}")
    print("Running tests for: ")
    cnt = 0
    print("    ")
    for test_file in test_files:
        print(f"{test_file}", end=" ")
        cnt += 1
        if cnt % 5 == 0:
            print("    ")
    print("\n")

    for test_file in test_files:
        print(f"--- Testing {test_file} ---")
        base_name, _ = os.path.splitext(test_file)
        example_file_path = os.path.join("examples", test_file)
        ans_file_path = os.path.join("examples", "ans", f"{base_name}.ans")
        ll_file = f"{base_name}.ll"
        executable_file = base_name

        # Check if the example file exists
        if not os.path.exists(example_file_path):
            print(f"Test {test_file} Failed: File Not Found")
            continue

        # Step 4: Run moon run
        moon_run_command = f"moon run main -- --file {example_file_path} > {ll_file}"
        stdout, stderr = run_command(moon_run_command)
        if "error:" in stderr.lower() or "error[" in stderr.lower():
            print(f"File {test_file} parsing Error")
            print(stderr)
            continue

        # Step 5: Compile with clang
        clang_command = f"clang {ll_file} runtime.c -o {executable_file}"
        # remove .ll
        _, stderr = run_command(clang_command)
        rm_ll_command = f"rm -f {ll_file}"
        run_command(rm_ll_command)
        if "error:" in stderr.lower() or "error[" in stderr.lower():
            print(f"Clang compilation failed for {test_file}")
            print(stderr)
            continue
        
        # Step 6: Run the executable
        run_executable_command = f"./{executable_file}"
        result, stderr = run_command(run_executable_command)
        # remove executable
        rm_executable_command = f"rm -f {executable_file}"
        run_command(rm_executable_command)
        if stderr:
            print(f"Error running executable for {test_file}")
            print(stderr)
            continue

        # Step 7: Compare with the answer
        if not os.path.exists(ans_file_path):
            print(f"Answer file not found for {test_file}. Creating one.")
            with open(ans_file_path, "w") as f:
                f.write(result)
        else:
            with open(ans_file_path, "r") as f:
                expected_result = f.read()
            if result != expected_result:
                print(f"Test File {test_file} Tested Failed: Current result is inconsistent with previous result.")
            else:
                print(f"Test {test_file} Passed!")

if __name__ == "__main__":
    main()
