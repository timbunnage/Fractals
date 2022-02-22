using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraController : MonoBehaviour
{
    float mouseSensitivity = 100f;
    float speed = 10f;
    Vector2 turn = new Vector2(0f, 0f);


    // Start is called before the first frame update
    void Start()
    {
        transform.localRotation = Quaternion.Euler(-turn.y, turn.x, 0f);
        transform.position = new Vector3(0f, 1f, 0f);
        

        Cursor.lockState = CursorLockMode.Locked;
    }

    // Update is called once per frame
    void Update()
    {
        // Movement
        float x = Input.GetAxis("Horizontal");
        float z = Input.GetAxis("Vertical");
        Vector3 m = transform.right * x + transform.forward * z;
        transform.position += m * speed * Time.deltaTime;

        // Rotation
        turn.x += Input.GetAxisRaw("Mouse X") * mouseSensitivity * Time.deltaTime;
        turn.y += Input.GetAxisRaw("Mouse Y") * mouseSensitivity * Time.deltaTime;
        turn.y = Mathf.Clamp(turn.y, -90f, 90f);  // Clamp between looking up/down
        transform.localRotation = Quaternion.Euler(-turn.y, turn.x, 0f);

    }
}
