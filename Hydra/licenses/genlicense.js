// this is for use with fastspring

var key = "-----BEGIN DSA PRIVATE KEY-----\n\
MIH3AgEAAkEAzKaHbgkiRpZB2tz2hUpk7Y7icIh3Zd5Vi086tVK9vcp+1e9zU6lN\n\
vW1nM0rNJzGWWWLCKsNvXxaoPQUOib7k1wIVAK/W4Zv5zFz1UsFaKF6jz2xDkFCN\n\
AkBCuPlrBeNgFi9LeCre5ZRvV1DUpvPcB4/HdIZNznOJTAUqURuCB6su1gBBOTa8\n\
2TfI2YyF0Sp5kKV0oLHWD69VAkBz3WE0WorE8zgVvupR/qwIw/J+ANM+kuxHuBg2\n\
gaweTRsFFy6b6gHZHWndKl3lEUZhz/CFxHwOgg081yY/1da2AhRymfSCNd5Q/IAy\n\
6M3629biylP9rA==\n\
-----END DSA PRIVATE KEY-----\n";

var intermediate = email.split("").reverse().join("");
dsaSign(key, intermediate);

// MCwCFHx82rhsrIRPGyvoiFcWPNZ6EE3IAhQv8Kbouk05NKnpXxXNcXPr/G1TwA==
