// Copyright 2008 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include <cstdio>

#include <vector>
#include <sstream>

#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>

#include "examples/scriptable/matrix/matrix_comp.h"
#include "boost/numeric/ublas/matrix.hpp"
#include "boost/numeric/ublas/lu.hpp"
#include "boost/numeric/ublas/io.hpp"


// constructor for the MatrixScriptableObject class -- does logging for debug
MatrixScriptableObject::MatrixScriptableObject()
    : pp::ScriptableObject() {
  printf("MatrixScriptableObject CTOR was called!\n");
  fflush(stdout);
}

// destructor for the MatrixScriptableObject class
MatrixScriptableObject::~MatrixScriptableObject() {
  printf("MatrixScriptableObject DTOR was called!\n");
  fflush(stdout);
}


// Converts an pp::Var to a number of type T.
// Type <class T> would normally be an int, float, double, unsigned int, etc.
// and so whether AsInt() or AsDouble() is used,
// we end up with it static_cast to the desired type...
template <class T>
class ppVarToNumber {
  public:
    ppVarToNumber() : conversion_error_(false) { }

    // functor that tries to convert |arg| to a number
    // Returns a value of type |T|
    // Indicates an error occurred by setting |conversion_error_| to true
    //   and putting an explanation in |error_message_|
    T operator()(const pp::Var& arg) {
       // clear out old/existing error & message
       conversion_error_ = false;
       error_message_ = "";

       if (arg.is_double()) {
         return static_cast<T>(arg.AsDouble());
       } else if (arg.is_int()) {
         return static_cast<T>(arg.AsInt());
       } else if (arg.is_bool()) {
         return static_cast<T>(arg.AsBool());
       } else if (arg.is_string()) {
         std::string result = arg.AsString();
         std::stringstream ss(result);  // create a string-stream from |result|
         T val = 0;
         // try to read a number (type T) from the string-stream
         if ((ss >> val).fail()) {
            printf("GetNthArrayElement: Error converting %s to a number\n",
                   result.c_str());
            conversion_error_ = true;
            error_message_ = "Error converting string ";
            error_message_ += arg.DebugString();
            error_message_ += " to a number";
         }
         return val;
       }
       // error case
       conversion_error_ = true;
       error_message_ = "Error converting unhandled type " + arg.DebugString()
                        + " to a number";
       return 0;
    }
    // Getters for conversion_error_ and error_message_
    bool conversion_error() const { return conversion_error_;}
    std::string error_message() const { return error_message_;}
  private:
    bool conversion_error_;
    std::string error_message_;
};

// GetNthArray takes a pp::Var |var| that is known to be a Javascript array
// and gets |index| element of the array.  Note that |index| has to be
// converted to a string and accessed as a property.  If an error_occurs
// converting retrieving the property with that index or converting the
// pp::Var for that property to a double, then |error_occurred| is set to true.
double GetNthArrayElement(const pp::Var& var, int index, bool* error_occurred) {
  pp::Var exception;
  *error_occurred = false;
  std::ostringstream oss;
  oss << index;

  bool has_prop = var.HasProperty(oss.str(), &exception);
  if (has_prop) {
    pp::Var indexVar = var.GetProperty(oss.str(), &exception);

    ppVarToNumber<double> dbl_converter;
    double value = dbl_converter(indexVar);
    if (dbl_converter.conversion_error()) {
      printf("GetNthArrayElement - error converting index %d: %s\n",
        index, dbl_converter.error_message().c_str());
      return 0.0;
    }
    return value;
  } else {
    printf("GetNthArrayElement: arg does not have a prop for index %d [%s]\n",
           index, var.DebugString().c_str());
    *error_occurred = true;
  }
  return 0.0;
}

//
// InvertMatrix -- this function is copied from the Effective UBLAS page
//   for boost libraries:
// http://www.crystalclearsoftware.com/cgi-bin/boost_wiki/wiki.pl?Effective_UBLAS
// The algorithm is here:
// http://www.crystalclearsoftware.com/cgi-bin/boost_wiki/wiki.pl?LU_Matrix_Inversion
// and is based on "Numerical Recipies in C", 2nd ed.,
// by Press, Teukolsky, Vetterling & Flannery.
//
template<class T>
bool InvertMatrix(const boost::numeric::ublas::matrix<T>& input,
  boost::numeric::ublas::matrix<T>& inverse) {
  // create a working copy of the input
  boost::numeric::ublas::matrix<T> A(input);
  // create a permutation matrix for the LU-factorization
  typedef boost::numeric::ublas::permutation_matrix<std::size_t> pmatrix;
  pmatrix pm(A.size1());

  // perform LU-factorization
  int res = boost::numeric::ublas::lu_factorize(A, pm);
  if (res != 0)
    return false;

  // create identity matrix of "inverse"
  inverse.assign(boost::numeric::ublas::identity_matrix<T> (A.size1()));

  // backsubstitute to get the inverse
  boost::numeric::ublas::lu_substitute(A, pm, inverse);
  return true;
}

// Convert a Boost matrix |boost_matrix| to a simple html table
// Uses ostringstream to write a mix of strings and numbers into a stream,
//  and then convert it all to a string
// The |title| and |border| inputs are for formatting the table
// The html table is returned as a string
std::string ConvertMatrixToHtml(
    std::string title, unsigned int border,
    boost::numeric::ublas::matrix<double> boost_matrix ) {
  std::ostringstream ss;
  ss << title << "<BR><table border=\"" << border << "\">";
  for (unsigned int i = 0; i < boost_matrix.size1(); ++i) {
    ss <<  "<tr>";
    for (unsigned int j = 0; j < boost_matrix.size2(); ++j) {
      ss << " <td>" << boost_matrix(i, j) << " </td>";
    }
    ss <<  "</tr>";
  }
  ss << "</table>";
  return ss.str();
}


// Called by Javascript -- this is a static method to process the matrix that
// is passed as a Javascript array object.  The array object is a 1-d array
// whose first two values are integer values for the width and height
// of the matrix, and then the rest of the values are the 2D matrix content as
// a series of string values.  This function ensures we have a single object
// argument, then grabs its "length" property, and then the properties for
// the indices: "0", "1" ... up to length-1
std::string MatrixScriptableObject::ComputeUsingArray(
    const std::vector<pp::Var>& args) {
  printf("ComputeUsingArray, arg_count=%d\n", args.size());
  fflush(stdout);

  // There should be exactly one arg, which should be an object
  if (args.size() != 1) {
    printf("Unexpected number of args\n");
    return "Unexpected number of args";
  }
  if (!args[0].is_object()) {
    printf("Arg is NOT an object\n");
    return "Arg from Javascript is not an object!";
  }

  pp::Var exception;  // Use initial "void" Var for exception
  pp::Var arg0 = args[0];
  pp::Var var_length = arg0.GetProperty("length", &exception);

  if (!exception.is_void()) {
    printf("Error getting 'length' of JS object\n");
    return "Error getting length property of JS object";
  }

  int length = var_length.AsInt();

  // The length should be > 2 since we always have a width and height plus data
  if (length <= 2) {
    // then we didn't get width, height, and then the cell values...
    printf("Invalid length (%d)\n", length);
    return "Error: Invalid length";
  }

  // grab the width and height
  bool error_occurred = false;
  int width = static_cast<int>(GetNthArrayElement(arg0, 0, &error_occurred));
  int height = static_cast<int>(GetNthArrayElement(arg0, 1, &error_occurred));

  boost::numeric::ublas::matrix<double>  initial_matrix(height, width);
  // the transpose will have |width| rows....instead of |width| columns
  boost::numeric::ublas::matrix<double> trans_matrix(width, height);

  int row = 0, column = 0;

  // Fill the initial_matrix with values from the JS array object
  for (int i = 2; i < length; ++i) {
    double cur_value = GetNthArrayElement(arg0, i, &error_occurred);
    if (error_occurred) {
      return "Error getting matrix values";
    } else {
      // got good value from Javascript array
      printf("Grabbed %g from array for %d,%d\n", cur_value, column, row);
      fflush(stdout);
      initial_matrix(row, column) = cur_value;
      ++column;
      if (column == width) {
        column = 0;
        ++row;
      }
    }
  }

  // Note -- throughout the program I pass in various values for the 3rd
  // argument |border| which controls the size of the border in the
  // html string that is created by ConvertMatrixToHtml.  There is not a
  // special reason for the different values -- but I wanted to call it
  // with different values so that the result visual effect in html can
  // be seen on the matrix.html web page.
  std::string full_message = ConvertMatrixToHtml(
    "Orig matrix from JS array", 1, initial_matrix);

  // transpose the matrix
  trans_matrix = boost::numeric::ublas::trans(initial_matrix);

  full_message += ConvertMatrixToHtml("Transposed matrix from JS array",
    2, trans_matrix);

  return full_message;
}

// Called by Javascript -- this is a static method to process the matrix that
// is passed as a series of doubles in |args|. The first two values are the
// width and height of the matrix -- the rest of the values are the array
// contents.
std::string MatrixScriptableObject::ComputeAnswer(
    const std::vector<pp::Var>& args) {
  std::vector<double> input_vector;

  if (args.size() < 2) {
    return "Error in ComputeAnswer, arg_count too small";
  }
  int matrix_width = 0, matrix_height = 0;

  ppVarToNumber<double> dbl_converter;
  ppVarToNumber<int> int_converter;

  matrix_width = int_converter(args[0]);
  if (int_converter.conversion_error()) {
    printf(" ComputeAnswer: %s\n", int_converter.error_message().c_str());
    return int_converter.error_message();
  }

  matrix_height = int_converter(args[1]);
  if (int_converter.conversion_error()) {
    printf(" ComputeAnswer: %s\n", int_converter.error_message().c_str());
    return int_converter.error_message();
  }

  if (matrix_width <= 0 || matrix_height <= 0) {
    printf("Invalid matrix sizes\n");
    return "Invalid matrix sizes";
  }

  for (unsigned int index = 2; index < args.size(); ++index) {
    double arg_value = dbl_converter(args[index]);
    if (dbl_converter.conversion_error()) {
      printf("arg %d ComputeAnswer: %s\n", index,
        dbl_converter.error_message().c_str());
      return dbl_converter.error_message();
    } else {
      input_vector.push_back(arg_value);
    }
  }

  // filling matrix data
  boost::numeric::ublas::matrix<double>
    matrix_data(matrix_height, matrix_width);

  int column = 0, row = 0;
  for ( std::vector<double>::iterator iter = input_vector.begin();
        iter != input_vector.end(); ++iter) {
    double value = *iter;
    printf(" row %d column %d %3.3g ", row, column, value);
    matrix_data(row, column) = value;
    ++column;
    if (column >= matrix_width) {
      column = 0;
      ++row;
    }
  }

  printf("Filled matrix_data...\n");
  fflush(stdout);

  std::string js_message;   // message to send back to Javascript
  js_message = ConvertMatrixToHtml("Original Matrix:", 3, matrix_data);

  if ((matrix_height == matrix_width) && matrix_height>0) {
    std::string inverted_matrix_string;
    printf("Inverting...height=%d width=%d\n", matrix_height, matrix_width);
    fflush(stdout);

    boost::numeric::ublas::matrix<double>
      inverted_matrix(matrix_height, matrix_width);

    bool can_be_inverted = InvertMatrix(matrix_data, inverted_matrix);

    if (can_be_inverted) {
      inverted_matrix_string = ConvertMatrixToHtml("Inverted Matrix:", 4,
        inverted_matrix);
      // now let's multiply matrix_data X inverted_matrix and print it
      // to visually double-check the inverse
      boost::numeric::ublas::matrix<double>
        prod_matrix(matrix_height, matrix_width);

      prod_matrix = prod(matrix_data, inverted_matrix);

      inverted_matrix_string += ConvertMatrixToHtml(
        "Matrix Multiply -- Original Matrix x Inverse Matrix:", 4, prod_matrix);
    } else {
      inverted_matrix_string = "MATRIX CANNOT BE INVERTED";
    }
    js_message += inverted_matrix_string;
  }

  return js_message;
}

// The Instance class.  One of these exists for each instance of your NaCl
// module on the web page.  The browser will ask the Module object to create
// a new Instance for each occurence of the <embed> tag that has these
// attributes:
//     type="application/x-ppapi-nacl-srpc"
//     nexes="ARM: hello_world_arm.nexe
//            ..."
// The Instance can return a ScriptableObject representing itself.  When the
// browser encounters JavaScript that wants to access the Instance, it calls
// the GetInstanceObject() method.  All the scripting work is done though
// the returned ScriptableObject.
class MatrixInstance : public pp::Instance {
 public:
  explicit MatrixInstance(PP_Instance instance) : pp::Instance(instance) {}
  virtual ~MatrixInstance() {}

  // The pp::Var takes over ownership of the MatrixInstance.
  virtual pp::Var GetInstanceObject() {
    MatrixScriptableObject* hw_object = new MatrixScriptableObject();
    return pp::Var(hw_object);
  }
};

// The Module class.  The browser calls the CreateInstance() method to create
// an instance of your NaCl module on the web page.
class MatrixModule : public pp::Module {
 public:
  MatrixModule() : pp::Module() {}
  virtual ~MatrixModule() {}

  // Create and return a MatrixInstance object.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new MatrixInstance(instance);
  }
};

// Factory function called by the browser when the module is first loaded.
// The browser keeps a singleton of this module.  It calls the
// CreateInstance() method on the object you return to make instances.  There
// is one instance per <embed> tag on the page.  This is the main binding
// point for your NaCl module with the browser.
namespace pp {
Module* CreateModule() {
  return new MatrixModule();
}
}  // namespace pp

