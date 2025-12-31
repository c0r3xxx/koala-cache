# TODO
- solve potential hash colission problem for images
- hide errors from outputs
- remove "#[allow(dead_code)]"


curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"username":"aaron","password":"0ekX8eIIC6Ft3P8W"}' \
  http://localhost:3000/login

/* db::create_user(
    &pool,
    &UserCredentials {
        username: "aaron".to_string(),
        password: "0ekX8eIIC6Ft3P8W".to_string(),
    },
)
.await
.unwrap(); */
