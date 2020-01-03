#!/bin/bash
export PATH="$PATH:`pwd`"
DEBUG_SCRIPT=0
if [ $DEBUG_SCRIPT -eq 1 ]; then
	echo "DepthK version"
	python2 ./depthk.py --version
	echo ""
	
	ps axfl
	cat /etc/lsb-release
	uname -a
	pwd
		
	echo "GREP command: Testing 1 "
	value=$( grep -c "depthk" depthk.py )
	if [ "$value" -ge 1 ]
	then
	  echo "Grep works"
	else
	  echo "NOT works"
	fi
echo "DepthK version 3.0 - Mon Dez 19 17:40:02 AMT 2016"
fi


# ------------- DepthK wrapper script to tests
# Usage: ./wrapper_script_tests.sh <[-p|]> <file.c|file.i>

# ESBMC violation properties
PROPERTY_FORGOTTEN_MEMORY_TAG="dereference failure: forgotten memory"
PROPERTY_INVALID_POINTER_TAG="dereference failure: invalid pointer"
PROPERTY_ARRAY_BOUND_VIOLATED_TAG="array bounds violated"
PROPERTY_ACCESS_OUT_TAG="dereference failure: Access to object out of bounds"
PROPERTY_INVALID_OBJECT_TAG="dereference failure: invalidated dynamic object"
PROPERTY_NULL_POINTER_TAG="dereference failure: NULL pointer"
PROPERTY_FREE_OFFSET_TAG="Operand of free must have zero pointer offset"
PROPERTY_FREE_ERROR_TAG="dereference failure: free() of non-dynamic memory"
PROPERTY_INVALID_OBJECT_FREE_TAG="dereference failure: invalidated dynamic object freed"
PROPERTY_INVALID_PORINTER_FREE_TAG="dereference failure: invalid pointer freed"
#PROPERTY_UNWIND_ASSERTION_LOOP_TAG="unwinding assertion loop" #É verificado dentro do DepthK, se for esse tipo, então o resultado é unknown.

# MEMSAFETY properties pattern
BENCHMARK_FALSE_VALID_MEMTRACK=${PROPERTY_FORGOTTEN_MEMORY_TAG}
BENCHMARK_FALSE_VALID_DEREF="(\|${PROPERTY_INVALID_POINTER_TAG}\|${PROPERTY_ARRAY_BOUND_VIOLATED_TAG}\|${PROPERTY_NULL_POINTER_TAG}\|${PROPERTY_ACCESS_OUT_TAG}\|${PROPERTY_INVALID_OBJECT_TAG}\|)"
BENCHMARK_FALSE_VALID_FREE="(\|${PROPERTY_FREE_OFFSET_TAG}\|${PROPERTY_FREE_ERROR_TAG}\|${PROPERTY_INVALID_OBJECT_FREE_TAG}\|${PROPERTY_INVALID_PORINTER_FREE_TAG}\|)"

# Benchmark result controlling flags
IS_MEMSAFETY_BENCHMARK=0
# Path to the DepthK tool
path_to_depthk="python2 ./depthk.py"

# Memsafety cmdline picked
do_memsafety=0
do_term=0
do_overflow=0
property_list=""

# Use parallel k-induction
parallel=0

getpwd=$( pwd )

while getopts "c:mhptv" arg; do
    case $arg in
        h)
            echo "Usage: $0 [options] path_to_benchmark
Options:
-h             Print this message
-c propfile    Specifythe given property file
-p             Using k-induction with parallel algorithm
-t             Testing a sample"
exit
            ;;
        c)
            # Given the lack of variation in the property file... we don't
            # actually interpret it. Instead we have the same options to all
            # tests (except for the memory checking ones), and define all the
            # error labels from other directories to be ERROR.
            #if ! grep -q __VERIFIER_error $OPTARG; then
	    cat $OPTARG > ./ALL.prp
            property_list="./ALL.prp"
            prp_overflow_result=$( grep -c "overflow" "$property_list")            

		if [ "$prp_overflow_result" -ge 1 ]; then
			do_overflow=1
	
		fi

		prp_mem_result=$( grep -c "valid-free" "$property_list")
		if [ "$prp_mem_result" -ge 1 ]; then
				do_memsafety=1
				IS_MEMSAFETY_BENCHMARK=1
		fi
	
		prp_term_result=$( grep -c "CHECK( init(main()), LTL(F end)" "$property_list")
		if [ "$prp_term_result" -ge 1 ]; then
				do_term=1
		fi
        ;;
	p) parallel=1
        ;;
	t) 		
		echo ""
		prpfile="$getpwd/samples/ALL.prp"
		opt_test="--debug --force-check-base-case --solver z3 --memlimit 15g --prp $prpfile  --extra-option-esbmc=\"--floatbv --no-bounds-check --no-pointer-check --no-div-by-zero-check \""
		run_test="${path_to_depthk} $opt_test $getpwd/samples/example1_true-unreach-call.c"
		result_check=$(timeout 895 bash -c "$run_test")
		echo "$result_check"
		exit
        ;;
	v) 

		echo "DepthK version 3.0 - Fri Jan  6 18:14:20 AMT 2017"
		exit	

        ;;
    esac
done

if [ -z "$property_list" ]; then
   benchmark=${BASH_ARGV[0]}
   directory=$(dirname "$benchmark")
   possible_file="$directory/ALL.prp"
   if [ -e "$possible_file" ]; then
      prp_mem_z_result=$( grep -c "LTL(G[ ]*(valid-free|valid-deref|valid-memtrack)" "$possible_file")
	  if [ "$prp_mem_z_result" -ge 1 ]; then      
        do_memsafety=1
 	    IS_MEMSAFETY_BENCHMARK=1
      fi
      prp_term_z_result=$( grep -c "LTL(F[ ]*" "$possible_file")
	  if [ "$prp_term_z_result" -ge 1 ]; then      
          do_term=1
      fi
   fi
fi

# Command line, common to all tests.
depthk_options=""
if test ${parallel} = 1; then
  if test ${do_memsafety} = 0; then
    depthk_options=" -g --force-check-base-case --k-induction-parallel --solver z3 --memlimit 14g --prp "$property_list" --extra-option-esbmc=\"--no-bounds-check --no-pointer-check --no-div-by-zero-check --no-assertions\""    
  else
    depthk_options=" -g --force-check-base-case --k-induction-parallel --solver z3 --memlimit 14g --prp "$property_list" --memory-leak-check --extra-option-esbmc=\"--floatbv --error-label ERROR\""    
  fi
else
    if test ${do_term} = 1; then
	depthk_options=" -g -y --force-check-base-case --solver z3 --termination-category --memlimit 14g --prp "$property_list" --extra-option-esbmc=\"--no-div-by-zero-check --force-malloc-success --state-hashing --no-align-check --floatbv --context-bound 2 --no-pointer-check --no-bounds-check --no-assertions\""
    elif test ${do_overflow} = 1; then
	depthk_options=" -g -w --force-check-base-case --solver z3 --memlimit 14g --overflow-check --prp "$property_list" --extra-option-esbmc=\"--no-div-by-zero-check --force-malloc-success --state-hashing --no-align-check --floatbv --context-bound 2 --no-pointer-check --no-bounds-check --overflow-check --no-assertions\""
    elif test ${do_memsafety} = 1; then
        depthk_options=" -g -x --force-check-base-case --solver z3 --memlimit 14g --prp "$property_list" --extra-option-esbmc=\"--no-div-by-zero-check --force-malloc-success --state-hashing --no-align-check --floatbv --context-bound 2 --memory-leak-check --no-assertions\""
    else
        depthk_options=" --force-check-base-case --solver z3 --memlimit 14g --prp "$property_list" --memory-safety-category --extra-option-esbmc=\"--no-div-by-zero-check --force-malloc-success --state-hashing --no-align-check --floatbv --context-bound 2 --no-pointer-check --no-bounds-check\""
    fi
fi

# Store the path to the file we're going to be checking.
benchmark=${BASH_ARGV[0]}
# Store the path to the file to write the witness if the sourcefile
# contains a bug and the tool returns False (Error found)
# witnesspath=$2

if test "${benchmark}" = ""; then
    echo "No benchmark given" >&2
    exit 1
fi

# The complete command to be executed
run_cmdline="${path_to_depthk} ${depthk_options} \"${benchmark}\";"
echo "$run_cmdline"
#exit
# Invoke our command, wrapped in a timeout so that we can
# postprocess the results. `timeout` is part of coreutils on debian and fedora.
result_check=$(bash -c "$run_cmdline")

#echo "${result_check}"

VPROP=$""

if test ${IS_MEMSAFETY_BENCHMARK} = 1; then

   false_valid_mamtrack=$(echo "${result_check}" |grep -c "${BENCHMARK_FALSE_VALID_MEMTRACK}")
   false_valid_deref=$(echo "${result_check}" |grep -c "${BENCHMARK_FALSE_VALID_DEREF}")
   false_valid_free=$(echo "${result_check}" |grep -c "${BENCHMARK_FALSE_VALID_FREE}")

   if [ "$false_valid_mamtrack" -gt 0 ]; then
      VPROP=$"(valid-memtrack)"
   elif [ "${false_valid_deref}" -gt 0 ]; then
      VPROP=$"(valid-deref)"
   elif [ "${false_valid_free}" -gt 0 ]; then
      VPROP=$"(valid-free)"
   fi
elif test ${do_overflow} = 1; then
    VPROP=$"(no-overflow)"
fi

failed=$(echo "${result_check}" |grep -c "FALSE")
success=$(echo "${result_check}" |grep -c "TRUE")

# Decide which result we determined here.
if [ "$failed" -gt 0 ]; then
    # Error path found
	
    if test ${do_term} = 1; then
       echo "FALSE(TERMINATION)"
    else
       echo "FALSE"${VPROP}
    fi
elif [ "$success" -gt 0 ]; then
    echo "TRUE"
else
    echo "UNKNOWN"
fi
