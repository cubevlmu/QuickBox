package me.cubevlmu.quickbox;

import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.RequiresApi;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class MainActivity extends android.app.Activity {

    private final List<ResolveInfo> allApps = new ArrayList<>();
    private final List<ResolveInfo> filteredApps = new ArrayList<>();

    private PackageManager pm;
    private AppAdapter adapter;
    private boolean imeShown;

    @Override
    protected void onPause() {
        super.onPause();
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        pm = getPackageManager();

        EditText searchBox = findViewById(R.id.searchBox);
        RecyclerView appRecyclerView = findViewById(R.id.appRecyclerView);

        Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);

        List<ResolveInfo> resolveInfos = pm.queryIntentActivities(mainIntent, 0);
        resolveInfos.sort(Comparator.comparing(info -> info.loadLabel(pm).toString(), String.CASE_INSENSITIVE_ORDER));

        allApps.addAll(resolveInfos);
        filteredApps.addAll(resolveInfos);

        adapter = new AppAdapter(filteredApps, pm, info -> {
            ComponentName componentName = new ComponentName(
                    info.activityInfo.packageName,
                    info.activityInfo.name
            );

            Intent launchIntent = new Intent(Intent.ACTION_MAIN);
            launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            launchIntent.setComponent(componentName);
            launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

            try {
                startActivity(launchIntent);
            } catch (Exception e) {
                Toast.makeText(this, R.string.launch_failed, Toast.LENGTH_SHORT).show();
            }
        });

        appRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        appRecyclerView.setAdapter(adapter);

        searchBox.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void afterTextChanged(Editable s) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                filterApps(s.toString());
            }
        });
        searchBox.setOnEditorActionListener((v, actionId, event) -> {
            if (!filteredApps.isEmpty()) {
                ResolveInfo first = filteredApps.get(0);
                ComponentName componentName = new ComponentName(
                        first.activityInfo.packageName,
                        first.activityInfo.name
                );
                Intent launchIntent = new Intent(Intent.ACTION_MAIN);
                launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);
                launchIntent.setComponent(componentName);
                launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                try {
                    startActivity(launchIntent);
                } catch (Exception e) {
                    Toast.makeText(this, R.string.launch_failed, Toast.LENGTH_SHORT).show();
                }
            }
            return true;
        });
        searchBox.requestFocus();
    }


    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && !imeShown) {
            EditText searchBox = findViewById(R.id.searchBox);
            searchBox.requestFocus();

            getWindow().getDecorView().postDelayed(() -> {
                android.view.inputmethod.InputMethodManager imm =
                        (android.view.inputmethod.InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
                if (imm != null) {
                    imm.showSoftInput(searchBox, android.view.inputmethod.InputMethodManager.SHOW_FORCED);
                }
            }, 100);
            imeShown = true;
        }
    }

    private void filterApps(String query) {
        filteredApps.clear();
        for (ResolveInfo info : allApps) {
            String label = info.loadLabel(pm).toString();
            if (label.toLowerCase().contains(query.toLowerCase())) {
                filteredApps.add(info);
            }
        }
        adapter.updateList(filteredApps);
    }
}
