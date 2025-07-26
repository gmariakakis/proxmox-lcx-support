package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/exec"
    "strconv"
    "strings"

    "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
    jwt.RegisteredClaims
}

func authorize(r *http.Request) bool {
    secret := os.Getenv("BOOTSTRAP_SECRET")
    if secret == "" {
        return false
    }
    auth := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
    token, err := jwt.Parse(auth, func(t *jwt.Token) (interface{}, error) {
        if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
            return nil, fmt.Errorf("bad alg")
        }
        return []byte(secret), nil
    })
    return err == nil && token.Valid
}

func nextVMID() string {
    out, _ := exec.Command("pct", "list").Output()
    lines := strings.Split(string(out), "\n")
    max := 100
    for _, l := range lines[1:] {
        f := strings.Fields(l)
        if len(f) > 0 {
            if id, err := strconv.Atoi(f[0]); err == nil && id > max {
                max = id
            }
        }
    }
    return strconv.Itoa(max + 1)
}

func provision(w http.ResponseWriter, r *http.Request) {
    if !authorize(r) {
        w.WriteHeader(http.StatusUnauthorized)
        return
    }
    vmid := nextVMID()
    cmd := exec.Command("./install.sh", "--vmid", vmid)
    out, err := cmd.CombinedOutput()
    if err != nil {
        log.Println(err)
        w.WriteHeader(http.StatusInternalServerError)
        if _, werr := w.Write(out); werr != nil {
            log.Println("failed to write response body:", werr)
        }
        return
    }
    resp := map[string]string{"vmid": vmid, "output": string(out)}
    if err := json.NewEncoder(w).Encode(resp); err != nil {
        log.Println("failed to encode response:", err)
    }
}

func main() {
    http.HandleFunc("/provision", func(w http.ResponseWriter, r *http.Request) {
        if r.Method == http.MethodPost {
            provision(w, r)
            return
        }
        w.WriteHeader(http.StatusMethodNotAllowed)
    })
    log.Println("listening on 127.0.0.1:8787")
    log.Fatal(http.ListenAndServe("127.0.0.1:8787", nil))
}
