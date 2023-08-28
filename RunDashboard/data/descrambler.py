import functions
import sys

if __name__ == "__main__":
    try:
        functions.descrambler(sys.argv[1])
    except Exception as e:
        print(e)
        print("arguments provided: ", sys.argv)
