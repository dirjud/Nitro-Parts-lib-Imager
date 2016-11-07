
#include "vpycallbacks.h"


static VPyCallbacks* globalInst=NULL;

VPyCallbacks* VPyCallbacks::getInst() {
    if (globalInst == NULL) globalInst = new VPyCallbacks;
    return globalInst;
}

VPyCallbacks::VPyCallbacks(): mHandler(NULL) {}

VPyCallbacks::~VPyCallbacks() {
   Py_XDECREF(mHandler); 
}


void VPyCallbacks::registerHandler(PyObject* func) {
    VPyCallbacks *self=getInst();
    Py_XDECREF(self->mHandler);
    self->mHandler = func;
    Py_XINCREF(self->mHandler);
}

bool VPyCallbacks::executeCallback(const char* name, void* userData) {

    VPyCallbacks *self=getInst();

    if (!self->mHandler) return false; // not handled
    
    // note if execute called from non python func it might not have a thread state
    // so this ensures we don't crash
    PyGILState_STATE st = PyGILState_Ensure();

    bool handled = false;
    
    PyObject *argList;
    printf ( "userData addr %p\n", userData );
    argList = Py_BuildValue("sk", name, (unsigned long)userData);

    PyObject* result = PyObject_CallObject(self->mHandler,argList);
    Py_DECREF(argList);
    if (result == NULL) {
        // TODO handler error, print trace perhaps?
        printf ( "Exception in the callback\n" );
        PyErr_Print(); 
    } else {
        if (result == Py_True) {
           handled = true; 
        }
        Py_DECREF(result);
    }

    PyGILState_Release(st);
    return handled; 
}


