package main

import (
	"fmt"
	"net/http"
	"strconv"
)

func fibo(n int) int {
	f := make([]int, n+1, n+2)
	if n < 2 {
		f = f[0:2]
	}
	f[0] = 0
	f[1] = 1
	for i := 2; i <= n; i++ {
		f[i] = f[i-1] + f[i-2]
	}
	return f[n]
}

func handler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	n := int(5)
	keys, ok := r.URL.Query()["n"]
	if ok && len(keys[0]) >= 1 {
		val, err := strconv.ParseInt(keys[0], 10, 64)
		if err != nil || val <= 0 {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		n = int(val)
	}

	w.Write([]byte(fmt.Sprintf("result = %d\n", fibo(n))))
}

func main() {
	addr := ":9090"
	http.HandleFunc("/fibo", handler)
	fmt.Printf("Starting server on: %+v\n", addr)
	err := http.ListenAndServe(addr, nil)
	if err != nil && err != http.ErrServerClosed {
		fmt.Printf("Failed to run http server: %v\n", err)
	}
}
