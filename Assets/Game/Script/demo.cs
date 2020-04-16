using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class demo : MonoBehaviour
{

    void Unity_Remap_float4(Vector4 In, Vector4 InMinMax, Vector4 OutMinMax, out Vector4 Out)
    {
        float temp = InMinMax.x;
        Vector4 tempVec = new Vector4(temp, temp, temp, temp);
        Out = tempVec + (In - tempVec) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
    }

    void Unity_Remap_float1(float In, Vector2 InMinMax, Vector2 OutMinMax, out float Out)
    {
        Out = OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
        //out = 0 + (0.4 - -1) * (1 - 0) / (1 - -1);
    }

    // Start is called before the first frame update
    void Start()
    {
        float inF = 0.4f;
        Vector2 InMinMax = new Vector2(-1, 1);
        Vector2 outMinMax = new Vector2(0, 1);
        float outF = -100;
        Unity_Remap_float1(inF, InMinMax, outMinMax, out outF);
        Debug.LogErrorFormat("outF = {0}", outF);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
