package me.cubevlmu.quickbox;

import android.annotation.SuppressLint;
import android.os.Build;

import java.lang.reflect.Method;

public class OSUtils {

    private static String getSystemProperty(String key) {
        String value = null;
        try {
            @SuppressLint("PrivateApi") Class<?> sp = Class.forName("android.os.SystemProperties");
            Method get = sp.getMethod("get", String.class);
            value = (String) get.invoke(null, key);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return value;
    }

}
