/* 1. Allocation functions doing the same work as the macros in the
      case where [Setup_for_gc] and [Restore_after_gc] are no-ops.
   2. Convenience functions related to allocation.
*/

#include <string.h>
#include "alloc.h"
#include "debugger.h"
#include "major_gc.h"
#include "memory.h"
#include "mlvalues.h"
#include "stacks.h"

#define Setup_for_gc
#define Restore_after_gc

value alloc (mlsize_t wosize, tag_t tag)
{
  value result;
  
  Assert (wosize > 0 && wosize <= Max_young_wosize);
  Alloc_small (result, wosize, tag);
  return result;
}

value alloc_tuple(mlsize_t n)
{
  return alloc(n, 0);
}

value alloc_string(mlsize_t len)
{
  value result;
  mlsize_t offset_index;
  mlsize_t wosize = (len + sizeof (value)) / sizeof (value);

  if (wosize <= Max_young_wosize) {
    Alloc_small (result, wosize, String_tag);
  }else{
    result = alloc_shr (wosize, String_tag);
  }
  Field (result, wosize - 1) = 0;
  offset_index = Bsize_wsize (wosize) - 1;
  Byte (result, offset_index) = offset_index - len;
  return result;
}

value alloc_final (mlsize_t len, final_fun fun, mlsize_t mem, mlsize_t max)
{
  value result = alloc_shr (len, Final_tag);

  Field (result, 0) = (value) fun;
  adjust_gc_speed (mem, max);
  return result;
}

value copy_double(double d)
{
  value res;

  Alloc_small(res, Double_wosize, Double_tag);
  Store_double_val(res, d);
  return res;
}

value copy_string(char * s)
{
  int len;
  value res;

  len = strlen(s);
  res = alloc_string(len);
  bcopy(s, String_val(res), len);
  return res;
}

value alloc_array(value (*funct) (char *), char ** arr)
{
  mlsize_t nbr, n;
  value v;

  nbr = 0;
  while (arr[nbr] != 0) nbr++;
  if (nbr == 0) {
    return Atom(0);
  } else {
    Push_roots(r, 1);
    r[0] = nbr < Max_young_wosize ? alloc(nbr, 0) : alloc_shr(nbr, 0);
    for (n = 0; n < nbr; n++)
      Field(r[0], n) = Val_long(0);
    for (n = 0; n < nbr; n++) {
      v = funct(arr[n]);
      modify(&Field(r[0], n), v);
    }
    v = r[0];
    Pop_roots();
    return v;
  }
}

value copy_string_array(char ** arr)
{
  return alloc_array(copy_string, arr);
}

int convert_flag_list(value list, int * flags)
{
  int res;
  res = 0;
  while (Tag_val(list) == 1) {
    res |= flags[Tag_val(Field(list, 0))];
    list = Field(list, 1);
  }
  return res;
}
