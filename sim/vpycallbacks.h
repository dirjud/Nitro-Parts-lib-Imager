
#ifndef __VPYCALLBACK_H
#define __VPYCALLBACK_H

#include <Python.h>


class VPyCallbacks {
   public:
      ~VPyCallbacks();


      static void registerHandler(PyObject* func);
      static bool executeCallback(const char* name, void* userData); 

   private:
      VPyCallbacks(); 
      PyObject* mHandler;
      static VPyCallbacks* getInst();

};
#endif
