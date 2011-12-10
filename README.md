# bbarchive.pm

A blackboard course archive is a nasty hive of inter-related xml.  I
just wanted to extract gradebook information to generate a student
portfolio for accreditation purposes.  I'm putting it here in case
there is a value to others.

I'm in the process of moving to an OO perl module interface (how
quaint).  Perhaps you have a better idea?


## components of bbarchive hash reference (object)
* path
* *.xml
* attempts (attempt_id -->  list of path,type hash)
* outcomes (outcome_id -> title, points hash)
* users (bb_id -> name, uid hash)
