using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScreenScale : MonoBehaviour
{
    public Material mat;
    public Vector2 pos;
    public float scale;
    public Camera cam;


    private void UpdateShader()
    {
        float aspect = (float)Screen.width / (float)Screen.height;

        float scaleX = scale;
        float scaleY = scale;

        if (aspect > 1f) 
            scaleY /= aspect;
        else 
            scaleX *= aspect;

        mat.SetVector("_Area", new Vector4(pos.x, pos.y, scaleX, scaleY));
    }

    private void UpdateCamera() {
        mat.SetVector("_CamPosition", cam.transform.position);
        mat.SetVector("_CamRotation", cam.transform.eulerAngles * Mathf.Deg2Rad);
    }

    void Update() {
        UpdateCamera();
    }

    void FixedUpdate()
    {
        // HandleInputs();
        UpdateShader();
    }
}
