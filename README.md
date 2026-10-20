# updates

Kho phát hành công khai cho các add-in của KCC. Kho này **chỉ chứa bộ cài và
manifest**; code nguồn nằm ở các repo private.

| App | Thư mục manifest | Tiền tố tag |
|---|---|---|
| XToolPro (SOLIDWORKS) | `xtoolpro/` | `xtoolpro-v` |
| ZWCAD add-in | `zwcad/` | `zwcad-v` |
| Rhino add-in | `rhino/` | `rhino-v` |
| Grasshopper plug-in | `grasshopper/` | `grasshopper-v` |

## Quy ước

- Mỗi bản phát hành là một GitHub Release với tag `<app>-v<version>`, ví dụ
  `xtoolpro-v3.3.46.170`. Release chỉ chứa bộ cài của đúng một app.
- Mỗi app có `<app>/latest.json`. App đọc file này qua
  `https://raw.githubusercontent.com/trongtkm/updates/main/<app>/latest.json`
  (không cần token, không dính giới hạn GitHub API).
- `latest.json` luôn có SHA256 của bộ cài. App phải kiểm hash trước khi chạy
  bộ cài và từ chối nếu thiếu hoặc lệch.
- Không bao giờ sửa hay xoá file của một release đã phát hành; có lỗi thì ra
  bản mới.

## Định dạng `latest.json`

```json
{
  "app": "xtoolpro",
  "version": "3.3.46.170",
  "url": "https://github.com/trongtkm/updates/releases/download/xtoolpro-v3.3.46.170/XToolProSetup-3.3.46.170.exe",
  "changelog": "https://github.com/trongtkm/updates/releases/tag/xtoolpro-v3.3.46.170",
  "published": "2026-10-20T10:00:00Z",
  "mandatory": { "value": false, "minVersion": null, "mode": 0 },
  "checksum": { "value": "<SHA256 hex>", "hashingAlgorithm": "SHA256" }
}
```

`version`, `url`, `checksum` là bắt buộc. Các trường `mandatory`, `checksum`
đúng tên với AutoUpdater.NET nên add-in .NET nào dùng thư viện đó cũng đọc được.

## Ra bản mới

Trên máy build (cần [GitHub CLI](https://cli.github.com/) đã `gh auth login`):

```powershell
cd C:\path\to\updates
git pull
.\tools\publish.ps1 -App xtoolpro -Version 3.3.46.170 `
    -Installer ..\SwITool\dist\XToolProSetup-3.3.46.170.exe `
    -Notes "Sửa lỗi DXF, nhanh hơn khi xuất bản vẽ"
```

Script tạo Release và tải bộ cài lên **trước**, rồi mới ghi `latest.json` và
push, nên máy người dùng không bao giờ thấy manifest trỏ tới file chưa có.
Script từ chối nếu `-Version` khác ProductVersion của file .exe, hoặc không mới hơn
bản trong `latest.json` hiện tại. Thêm `-Mandatory` để bắt buộc cập nhật, `-DryRun`
để xem trước mà không đẩy gì.
