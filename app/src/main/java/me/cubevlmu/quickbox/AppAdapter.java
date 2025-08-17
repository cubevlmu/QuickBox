package me.cubevlmu.quickbox;

import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;

public class AppAdapter extends RecyclerView.Adapter<AppAdapter.ViewHolder> {

    public interface OnAppClickListener {
        void onAppClick(ResolveInfo info);
    }

    private final List<ResolveInfo> apps;
    private final PackageManager pm;
    private final OnAppClickListener clickListener;

    public AppAdapter(List<ResolveInfo> apps, PackageManager pm, OnAppClickListener listener) {
        this.apps = new ArrayList<>(apps);
        this.pm = pm;
        this.clickListener = listener;
    }

    public static class ViewHolder extends RecyclerView.ViewHolder {
        ImageView icon;
        TextView name;

        public ViewHolder(View itemView) {
            super(itemView);
            icon = itemView.findViewById(R.id.appIcon);
            name = itemView.findViewById(R.id.appName);
        }
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.app_item, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        ResolveInfo app = apps.get(position);
        holder.name.setText(app.loadLabel(pm));
        holder.icon.setImageDrawable(app.loadIcon(pm));
        holder.itemView.setOnClickListener(v -> clickListener.onAppClick(app));
    }

    @Override
    public int getItemCount() {
        return apps.size();
    }

    @SuppressLint("NotifyDataSetChanged")
    public void updateList(List<ResolveInfo> newApps) {
        apps.clear();
        apps.addAll(newApps);
        notifyDataSetChanged();
    }
}
